@tool
extends Node2D
class_name DialogueEvent

## Nodo invisible que ejecuta acciones al recibir un evento remoto
## desde diálogos vía GameManager.trigger_event("nombre_nodo").

signal event_executed()

@export var event_id: String = "":
	set(value):
		event_id = value
		if Engine.is_editor_hint():
			_update_editor_label()

@export var one_shot: bool = true
@export var persistence_id: String = ""
@export var actions: Array[ActionResource] = []

var _has_triggered: bool = false

func _ready() -> void:
	if persistence_id.is_empty():
		persistence_id = PersistenceIdHelper.generate_id(self, "evt")
	if Engine.is_editor_hint():
		_update_editor_label()
		return
	_restore_state()
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		gm.game_event.connect(_on_game_event)

func _on_game_event(event_name: String, _event_data: Variant = null) -> void:
	if event_name != event_id and event_name != name:
		return
	if one_shot and _has_triggered:
		return
	_has_triggered = true
	_persist_state()
	_run_actions()
	event_executed.emit()

func _run_actions() -> void:
	for act: ActionResource in actions:
		if act:
			act.execute(self)

func _restore_state() -> void:
	if persistence_id.is_empty():
		return
	var wsm: Node = get_node_or_null("/root/WorldStateManager")
	if wsm and wsm.has_state(persistence_id):
		var data: Dictionary = wsm.load_state(persistence_id)
		_has_triggered = data.get("has_triggered", false)

func _persist_state() -> void:
	if persistence_id.is_empty():
		return
	var wsm: Node = get_node_or_null("/root/WorldStateManager")
	if wsm:
		wsm.save_state(persistence_id, {"has_triggered": _has_triggered})

func _update_editor_label() -> void:
	queue_redraw()

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	# Dibujar icono visual en el editor para que sea localizable
	draw_circle(Vector2.ZERO, 12.0, Color(0.9, 0.3, 0.1, 0.6))
	draw_arc(Vector2.ZERO, 14.0, 0, TAU, 32, Color.WHITE, 2.0)
	var label: String = event_id if not event_id.is_empty() else name
	draw_string(ThemeDB.fallback_font, Vector2(-30, 28), label, HORIZONTAL_ALIGNMENT_CENTER, 60, 10, Color.WHITE)
