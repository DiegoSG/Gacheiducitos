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
## En ON_ENTER_AND_EXIT un "uso" es un ciclo completo entrar + salir.
@export var one_shot: bool = true
## ID único para persistencia. Si está vacío, el estado solo dura mientras el jugador siga en este nivel (clave efímera).
@export var persistence_id: String = ""

@export_group("Condición")
## En ON_ENTER, ON_EXIT, INTERACT, AUTO_START y force_trigger: condición verdadera (o sin condición) ejecuta
## actions_if_true y falsa ejecuta actions_if_false.
## En ON_ENTER_AND_EXIT la condición se evalúa solo al entrar: si es falsa no se ejecuta nada
## (ni al entrar ni al salir).
@export var require_condition: bool = false
@export var condition_flag: String = ""
@export var condition_expected_value: String = "true"

@export_group("Acciones")
## Acciones ejecutadas si la condición es verdadera (o no hay condición).
## En ON_ENTER_AND_EXIT son las acciones de entrada.
@export var actions_if_true: Array[ActionResource] = []
## Acciones ejecutadas si la condición es falsa.
## En ON_ENTER_AND_EXIT son las acciones de salida (nunca se ejecuta actions_if_true al salir).
@export var actions_if_false: Array[ActionResource] = []

var _has_triggered: bool = false
var _is_running: bool = false
## Solo ON_ENTER_AND_EXIT: true entre una entrada que ejecutó actions_if_true y su salida correspondiente.
var _cycle_open: bool = false
var _agents_inside: Array[Node2D] = []
var _persistence_key: String = ""

func _ready() -> void:
	_persistence_key = PersistenceIdHelper.runtime_key(self, persistence_id)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_restore_state()
	if trigger_mode == TriggerMode.AUTO_START and not _has_triggered:
		call_deferred("_attempt_trigger")

func _restore_state() -> void:
	if _persistence_key.is_empty():
		return
	if WorldStateManager.has_state(_persistence_key):
		_has_triggered = WorldStateManager.load_state(_persistence_key).get("has_triggered", false)

func _on_body_entered(body: Node2D) -> void:
	if not _agents_inside.has(body):
		_agents_inside.append(body)

	if trigger_mode == TriggerMode.ON_ENTER:
		_attempt_trigger()
	elif trigger_mode == TriggerMode.ON_ENTER_AND_EXIT:
		_begin_cycle()

func _on_body_exited(body: Node2D) -> void:
	if _agents_inside.has(body):
		_agents_inside.erase(body)

	if trigger_mode == TriggerMode.ON_EXIT:
		_attempt_trigger()
	elif trigger_mode == TriggerMode.ON_ENTER_AND_EXIT:
		_agents_inside = _agents_inside.filter(func(n: Node2D) -> bool: return is_instance_valid(n))
		if _agents_inside.is_empty():
			_end_cycle()

func _unhandled_input(event: InputEvent) -> void:
	if trigger_mode == TriggerMode.INTERACT and event.is_action_pressed("ui_accept"):
		_agents_inside = _agents_inside.filter(func(n: Node2D) -> bool: return is_instance_valid(n))
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

## Evalúa la condición configurada. Sin condición (o sin flag) devuelve true.
func _evaluate_condition() -> bool:
	if not require_condition or condition_flag.is_empty():
		return true
	var actual_val: Variant = NarrativeManager.get_flag(condition_flag)
	var expected: Variant = ActionResource.parse_value(condition_expected_value)
	return str(actual_val) == str(expected)

## Disparo estándar (ON_ENTER, ON_EXIT, INTERACT, AUTO_START, force_trigger):
## condición verdadera o ausente -> actions_if_true, falsa -> actions_if_false.
func _attempt_trigger() -> void:
	if not _can_trigger(): return

	if one_shot:
		_has_triggered = true
		_persist_state()
	_is_running = true

	var array_to_run: Array[ActionResource] = actions_if_true if _evaluate_condition() else actions_if_false
	await ActionRunner.run(array_to_run, self)
	_is_running = false

## ON_ENTER_AND_EXIT: entrada. Ejecuta actions_if_true si la condición se cumple (o no hay condición);
## si es falsa no ejecuta nada y no abre el ciclo (la salida tampoco ejecutará nada).
func _begin_cycle() -> void:
	if _cycle_open or not _can_trigger(): return
	if not _evaluate_condition(): return

	_cycle_open = true
	_is_running = true
	await ActionRunner.run(actions_if_true, self)
	_is_running = false

## ON_ENTER_AND_EXIT: salida. Solo ejecuta actions_if_false si la entrada abrió el ciclo.
## Con one_shot, el ciclo completo (entrar + salir) consume el trigger.
func _end_cycle() -> void:
	if not _cycle_open: return
	_cycle_open = false

	# Si las acciones de entrada siguen corriendo, esperar a que terminen antes de las de salida
	while _is_running:
		if not is_inside_tree():
			return
		await get_tree().process_frame

	if one_shot:
		_has_triggered = true
		_persist_state()

	_is_running = true
	await ActionRunner.run(actions_if_false, self)
	_is_running = false

func _persist_state() -> void:
	if _persistence_key.is_empty():
		return
	WorldStateManager.save_state(_persistence_key, {"has_triggered": _has_triggered})
