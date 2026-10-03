class_name VariableWatcher
extends Node

## Vigila un ConditionSet y dispara un GameTrigger en la transición falso -> verdadero.

@export var conditions: ConditionSet
## GameTrigger a disparar con force_trigger(). Vacío = el nodo padre.
@export var target_trigger: NodePath
@export var one_shot: bool = true
## Evalúa la condición al entrar en escena (dispara si ya es verdadera).
@export var check_on_ready: bool = true
## ID único para recordar entre niveles que ya disparó (solo con one_shot).
@export var persistence_id: String = ""

var _persistence_key: String = ""
var _has_fired: bool = false
var _last_result: bool = false

func _ready() -> void:
	_persistence_key = PersistenceIdHelper.runtime_key(self, persistence_id)
	if one_shot and WorldStateManager.has_state(_persistence_key):
		_has_fired = WorldStateManager.load_state(_persistence_key).get("has_fired", false)
	if _has_fired:
		return
	GameVariables.variable_changed.connect(_on_variable_changed)
	if check_on_ready:
		# Diferido para que el resto de la escena (el trigger objetivo) esté listo
		_last_result = false
		call_deferred("_evaluate")
	else:
		_last_result = _current_result()

func _on_variable_changed(_path: String, _value: Variant) -> void:
	_evaluate()

func _current_result() -> bool:
	return conditions != null and conditions.evaluate()

func _evaluate() -> void:
	if _has_fired:
		return
	var result: bool = _current_result()
	var rising: bool = result and not _last_result
	_last_result = result
	if rising:
		_fire()

func _fire() -> void:
	var target: Node = get_parent() if target_trigger.is_empty() else get_node_or_null(target_trigger)
	var trigger: GameTrigger = target as GameTrigger
	if trigger == null:
		push_warning("VariableWatcher '%s': el objetivo no es un GameTrigger." % name)
		return
	if one_shot:
		_has_fired = true
		WorldStateManager.save_state(_persistence_key, {"has_fired": true})
		GameVariables.variable_changed.disconnect(_on_variable_changed)
	trigger.force_trigger()
