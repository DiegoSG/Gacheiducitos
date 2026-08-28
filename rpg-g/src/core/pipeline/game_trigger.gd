class_name GameTrigger
extends Area2D

## Un trigger general que evalúa variables de juego y ejecuta acciones ya sea en
## secuencia o todas a la vez.

enum TriggerMode {
	ON_ENTER, ## Se activa al pisarlo
	ON_EXIT, ## Se activa al salir del área
	INTERACT, ## Se activa usando el botón de acción estando dentro
	AUTO_START ## Se activa automáticamente en cuanto carga la escena
}

@export var trigger_mode: TriggerMode = TriggerMode.ON_ENTER
@export var one_shot: bool = true

@export_group("Condición")
@export var require_condition: bool = false
@export var condition_flag: String = ""
@export var condition_expected_value: String = "true"

@export_group("Acciones")
@export var actions_if_true: Array[ActionResource] = []
@export var actions_if_false: Array[ActionResource] = []

var _has_triggered: bool = false
var _is_running: bool = false
var _agents_inside: Array[Node2D] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if trigger_mode == TriggerMode.AUTO_START:
		call_deferred("_attempt_trigger")

func _on_body_entered(body: Node2D) -> void:
	if not _agents_inside.has(body):
		_agents_inside.append(body)
		
	var activated = false
	if trigger_mode == TriggerMode.ON_ENTER:
		activated = _can_trigger()
		_attempt_trigger()
		
	print("[GameTrigger: body_entered] '%s' cruzó el área de '%s'. Activado: %s" % [body.name, name, activated])

func _on_body_exited(body: Node2D) -> void:
	if _agents_inside.has(body):
		_agents_inside.erase(body)
		
	var activated = false
	if trigger_mode == TriggerMode.ON_EXIT:
		activated = _can_trigger()
		_attempt_trigger()
		
	print("[GameTrigger: body_exited] '%s' salió del área de '%s'. Activado: %s" % [body.name, name, activated])

func _unhandled_input(event: InputEvent) -> void:
	if trigger_mode == TriggerMode.INTERACT and event.is_action_pressed("ui_accept"):
		_agents_inside = _agents_inside.filter(func(n): return is_instance_valid(n))
		if _agents_inside.size() > 0:
			get_viewport().set_input_as_handled()
			_attempt_trigger()

## Por si se llama directamente al trigger a través de un ActionableFinder manual
func action() -> void:
	if trigger_mode != TriggerMode.INTERACT: return
	print("[GameTrigger: action] Interacción táctil con '%s'. Activado: %s" % [name, _can_trigger()])
	_attempt_trigger()

## Permite que cualquier otro nodo (u otra acción) lo dispare a la fuerza
func force_trigger() -> void:
	print("[GameTrigger: force] '%s' fue forzado vía código." % name)
	_attempt_trigger()

func _can_trigger() -> bool:
	if _has_triggered and one_shot: return false
	if _is_running: return false
	return true

func _attempt_trigger() -> void:
	if not _can_trigger(): return
	
	_has_triggered = true
	_is_running = true
	
	var array_to_run: Array[ActionResource] = actions_if_true
	
	# Evaluar condición
	if require_condition and condition_flag != "":
		var narrative_manager = get_tree().root.get_node_or_null("NarrativeManager")
		if narrative_manager:
			var actual_val = narrative_manager.get_flag(condition_flag)
			var expected = _str_to_variant(condition_expected_value)
			
			if str(actual_val) != str(expected):
				array_to_run = actions_if_false
				
	await _run_actions(array_to_run)
	_is_running = false

func _str_to_variant(val: String) -> Variant:
	var l_val = val.to_lower()
	if l_val == "true" or l_val == "verdadero": return true
	if l_val == "false" or l_val == "falso": return false
	if val.is_valid_int(): return val.to_int()
	return val

func _run_actions(array: Array[ActionResource]) -> void:
	if array.is_empty(): return
	
	# Usamos un pequeño diccionario para que la lambda pueda modificar el valor por referencia
	var state = {"waiting": false}
	var on_action_done = func(): state.waiting = false
	
	for act in array:
		if not act: continue
		
		# Si la accion NO dice que debamos esperar a que termine, 
		# la disparamos y pasamos inmediatamente a la siguiente.
		if not act.wait_to_finish:
			act.execute(self)
			continue
			
		# Si ES wait_to_finish, nos preparamos para esperar su señal
		state.waiting = true
		if not act.is_connected("finished", on_action_done):
			act.finished.connect(on_action_done, CONNECT_ONE_SHOT)
			
		act.execute(self)
		
		# Esperamos frame por frame hasta que la señal "finished" apague la variable
		while state.waiting:
			if not is_inside_tree() or get_tree() == null:
				return
			await get_tree().process_frame
