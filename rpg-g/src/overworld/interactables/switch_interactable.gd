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

var _persistence_key: String = ""

func _ready() -> void:
	_persistence_key = PersistenceIdHelper.runtime_key(self, persistence_id)
	collision_layer = CollisionLayers.ACTIONABLE
	collision_mask = 0
	_update_visuals()
	_restore_state()

func _restore_state() -> void:
	if _persistence_key.is_empty():
		return
	if WorldStateManager.has_state(_persistence_key):
		is_on = WorldStateManager.load_state(_persistence_key).get("is_on", false)

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
		ActionRunner.run(trigger_actions, self)
	else:
		turned_off.emit()
		ActionRunner.run(off_actions, self)

	_persist_state()

func _persist_state() -> void:
	if _persistence_key.is_empty():
		return
	WorldStateManager.save_state(_persistence_key, {"is_on": is_on})
