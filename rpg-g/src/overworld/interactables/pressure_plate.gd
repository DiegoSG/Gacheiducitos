@tool
extends Area2D
class_name PressurePlate

## Placa de presión / Trigger interactivo de piso que dispara eventos al entrar y al salir.

signal pressed()
signal released()
signal state_changed(is_pressed: bool)

@export var is_pressed: bool = false:
	set(value):
		if is_pressed == value:
			return
		is_pressed = value
		_update_visuals()

@export var one_shot: bool = false ## Si se presiona una sola vez y no vuelve a subir

@export_group("Persistencia")
@export var persistence_id: String = ""

@export_group("Acciones de Eventos")
@export var on_enter_actions: Array[ActionResource] = [] ## Acciones que se ejecutan al entrar/pisar
@export var on_exit_actions: Array[ActionResource] = []  ## Acciones que se ejecutan al salir/despresionar

@export_group("Texturas")
@export var texture_up: Texture2D = preload("res://assets/sprites/pressure_plate.svg"):
	set(value):
		texture_up = value
		_update_visuals()

@export var texture_down: Texture2D = preload("res://assets/sprites/pressure_plate_down.svg"):
	set(value):
		texture_down = value
		_update_visuals()

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null

var _agents_inside: Array[Node2D] = []
var _has_triggered: bool = false
var _persistence_key: String = ""

func _ready() -> void:
	_persistence_key = PersistenceIdHelper.runtime_key(self, persistence_id)
	collision_layer = 0
	collision_mask = CollisionLayers.PLAYER
	if not Engine.is_editor_hint():
		if not body_entered.is_connected(_on_body_entered):
			body_entered.connect(_on_body_entered)
		if not body_exited.is_connected(_on_body_exited):
			body_exited.connect(_on_body_exited)
	_restore_state()
	_update_visuals()

func _update_visuals() -> void:
	if not is_node_ready():
		return
	if has_node("Sprite2D"):
		var s: Sprite2D = $Sprite2D
		s.texture = texture_down if is_pressed else texture_up

func _on_body_entered(body: Node2D) -> void:
	if not _agents_inside.has(body):
		_agents_inside.append(body)
		
	if not is_pressed:
		if one_shot and _has_triggered:
			return
		_has_triggered = true
		is_pressed = true
		_persist_state()
		pressed.emit()
		state_changed.emit(true)
		ActionRunner.run(on_enter_actions, self)

func _on_body_exited(body: Node2D) -> void:
	if _agents_inside.has(body):
		_agents_inside.erase(body)
		
	_agents_inside = _agents_inside.filter(func(a: Node2D) -> bool: return is_instance_valid(a))
	if _agents_inside.is_empty() and is_pressed:
		if one_shot:
			return
		is_pressed = false
		_persist_state()
		released.emit()
		state_changed.emit(false)
		ActionRunner.run(on_exit_actions, self)

func _restore_state() -> void:
	if Engine.is_editor_hint() or _persistence_key.is_empty():
		return
	if WorldStateManager.has_state(_persistence_key):
		var data: Dictionary = WorldStateManager.load_state(_persistence_key)
		_has_triggered = data.get("has_triggered", false)
		is_pressed = data.get("is_pressed", false)

func _persist_state() -> void:
	if Engine.is_editor_hint() or _persistence_key.is_empty():
		return
	WorldStateManager.save_state(_persistence_key, {
		"has_triggered": _has_triggered,
		"is_pressed": is_pressed
	})
