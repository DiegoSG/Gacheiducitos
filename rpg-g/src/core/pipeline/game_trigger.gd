class_name GameTrigger
extends Area2D

## Un trigger general que evalúa variables de juego y ejecuta acciones tanto al entrar, al salir o por interacción.

enum TriggerMode {
	ON_ENTER,        ## Se activa al pisarlo
	ON_EXIT,         ## Se activa al salir del área
	ON_ENTER_AND_EXIT, ## Ejecuta una lista al entrar y otra lista distinta al salir
	INTERACT,        ## Se activa usando el botón de acción estando dentro
	AUTO_START       ## Se activa automáticamente en cuanto carga la escena
}

@export var trigger_mode: TriggerMode = TriggerMode.ON_ENTER
@export var one_shot: bool = true
## ID único para persistencia. Si está vacío, no se persiste.
@export var persistence_id: String = ""

@export_group("Condición")
@export var require_condition: bool = false
@export var condition_flag: String = ""
@export var condition_expected_value: String = "true"

@export_group("Acciones")
## Acciones ejecutadas en ON_ENTER, INTERACT, AUTO_START o si la condición es verdadera
@export var actions_if_true: Array[ActionResource] = []
## Acciones ejecutadas en ON_EXIT (en modo ON_ENTER_AND_EXIT) o si la condición es falsa
@export var actions_if_false: Array[ActionResource] = []

var _has_triggered: bool = false
var _is_running: bool = false
var _agents_inside: Array[Node2D] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_restore_state()
	if trigger_mode == TriggerMode.AUTO_START and not _has_triggered:
		call_deferred("_attempt_trigger")

func _restore_state() -> void:
	if persistence_id.is_empty():
		return
	var wsm := get_node_or_null("/root/WorldStateManager")
	if wsm and wsm.has_state(persistence_id):
		_has_triggered = wsm.load_state(persistence_id).get("has_triggered", false)

func _on_body_entered(body: Node2D) -> void:
	if not _agents_inside.has(body):
		_agents_inside.append(body)

	if trigger_mode == TriggerMode.ON_ENTER or trigger_mode == TriggerMode.ON_ENTER_AND_EXIT:
		_attempt_trigger(actions_if_true)

func _on_body_exited(body: Node2D) -> void:
	if _agents_inside.has(body):
		_agents_inside.erase(body)

	if trigger_mode == TriggerMode.ON_EXIT:
		_attempt_trigger(actions_if_true)
	elif trigger_mode == TriggerMode.ON_ENTER_AND_EXIT:
		_attempt_trigger(actions_if_false)

func _unhandled_input(event: InputEvent) -> void:
	if trigger_mode == TriggerMode.INTERACT and event.is_action_pressed("ui_accept"):
		_agents_inside = _agents_inside.filter(func(n): return is_instance_valid(n))
		if _agents_inside.size() > 0:
			get_viewport().set_input_as_handled()
			_attempt_trigger()

## Por si se llama directamente al trigger a través de un ActionableFinder manual
func action() -> void:
	if trigger_mode != TriggerMode.INTERACT:
		return
	_attempt_trigger()

## Permite que cualquier otro nodo (u otra acción) lo dispare a la fuerza
func force_trigger() -> void:
	_attempt_trigger()

func _can_trigger() -> bool:
	if _has_triggered and one_shot: return false
	if _is_running: return false
	return true

func _attempt_trigger(override_actions: Array[ActionResource] = []) -> void:
	if not _can_trigger(): return
	
	if one_shot:
		_has_triggered = true
		_persist_state()
	_is_running = true
	
	var array_to_run: Array[ActionResource] = override_actions if not override_actions.is_empty() else actions_if_true
	
	# Evaluar condición si no es override directo
	if override_actions.is_empty() and require_condition and not condition_flag.is_empty():
		var narrative_manager: Node = get_tree().root.get_node_or_null("NarrativeManager") if get_tree() and get_tree().root else null
		if narrative_manager:
			var actual_val: Variant = narrative_manager.get_flag(condition_flag)
			var expected: Variant = _str_to_variant(condition_expected_value)

			if str(actual_val) != str(expected):
				array_to_run = actions_if_false

	await _run_actions(array_to_run)
	_is_running = false

func _str_to_variant(val: String) -> Variant:
	var l_val: String = val.to_lower()
	if l_val == "true" or l_val == "verdadero":
		return true
	if l_val == "false" or l_val == "falso":
		return false
	if val.is_valid_int():
		return val.to_int()
	return val

func _run_actions(array: Array[ActionResource]) -> void:
	if array.is_empty(): return
	
	var state: Dictionary = {"waiting": false}
	var on_action_done: Callable = func() -> void: state.waiting = false

	for act: ActionResource in array:
		if not act:
			continue

		if not act.wait_to_finish:
			act.execute(self)
			continue

		state.waiting = true
		if act.is_connected("finished", on_action_done):
			act.finished.disconnect(on_action_done)
		act.finished.connect(on_action_done, CONNECT_ONE_SHOT)

		act.execute(self)

		while state.waiting:
			if not is_inside_tree() or get_tree() == null:
				return
			await get_tree().process_frame

func _persist_state() -> void:
	if persistence_id.is_empty():
		return
	var wsm := get_node_or_null("/root/WorldStateManager")
	if wsm:
		wsm.save_state(persistence_id, {"has_triggered": _has_triggered})
