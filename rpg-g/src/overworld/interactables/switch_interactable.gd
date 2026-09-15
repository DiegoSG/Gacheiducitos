@tool
extends Actionable
class_name SwitchInteractable

## Interruptor / Palanca interactuable para activar secuencias y compuertas.

signal state_changed(is_on: bool)
signal turned_on()
signal turned_off()

@export var is_on: bool = false:
	set(value):
		is_on = value
		_update_visuals()

@export var is_toggleable: bool = true ## Si permite alternar on/off o es de un solo uso
@export var trigger_actions: Array[ActionResource] = [] ## Acciones a disparar al activarse
@export var off_actions: Array[ActionResource] = [] ## Acciones al apagarse (si es toggleable)

@export_group("Texturas")
@export var texture_off: Texture2D = preload("res://assets/sprites/switch_off.svg"):
	set(value):
		texture_off = value
		_update_visuals()

@export var texture_on: Texture2D = preload("res://assets/sprites/switch_on.svg"):
	set(value):
		texture_on = value
		_update_visuals()

@export_group("Persistencia")
@export var persistence_id: String = ""

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null

func _ready() -> void:
	# Layer 5 (16) para ser detectable por ActionableFinder del player
	collision_layer = 16
	collision_mask = 0
	_update_visuals()
	_restore_state()

func _restore_state() -> void:
	if persistence_id.is_empty():
		return
	var wsm := get_node_or_null("/root/WorldStateManager")
	if wsm and wsm.has_state(persistence_id):
		is_on = wsm.load_state(persistence_id).get("is_on", false)

func _update_visuals() -> void:
	if not is_node_ready():
		return
	if has_node("Sprite2D"):
		var s: Sprite2D = $Sprite2D
		s.texture = texture_on if is_on else texture_off

func action() -> void:
	if not is_toggleable and is_on:
		return

	is_on = not is_on
	state_changed.emit(is_on)

	if is_on:
		turned_on.emit()
		_run_actions(trigger_actions)
	else:
		turned_off.emit()
		_run_actions(off_actions)

	_persist_state()

func _persist_state() -> void:
	if persistence_id.is_empty():
		return
	var wsm := get_node_or_null("/root/WorldStateManager")
	if wsm:
		wsm.save_state(persistence_id, {"is_on": is_on})

func _run_actions(actions: Array[ActionResource]) -> void:
	for act in actions:
		if act:
			act.execute(self)
