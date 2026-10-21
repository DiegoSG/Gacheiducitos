class_name VariableWatcher
extends Node

## Watches a ConditionSet and fires a GameTrigger on the false -> true transition.

@export var conditions: ConditionSet
## GameTrigger to fire with force_trigger(). Empty = the parent node.
@export var target_trigger: NodePath
@export var one_shot: bool = true
## Evaluates the condition on entering the scene (fires if already true).
@export var check_on_ready: bool = true
## Unique ID to remember across levels that it already fired (only with one_shot).
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
		# Deferred so the rest of the scene (the target trigger) is ready
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
		push_warning("VariableWatcher '%s': the target is not a GameTrigger." % name)
		return
	if one_shot:
		_has_fired = true
		WorldStateManager.save_state(_persistence_key, {"has_fired": true})
		GameVariables.variable_changed.disconnect(_on_variable_changed)
	trigger.force_trigger()
