@tool
extends Area2D
class_name LevelPortal

signal portal_triggered(target_level_path: String, target_arrival_id: String)
signal opened()
signal locked()
signal unlocked()

enum Mode {
	PORTAL, ## Se activa automáticamente al pisar el área
	DOOR    ## Se activa interactuando con el botón de acción (E / Espacio / A)
}

@export_group("Tipo de Acceso")
## Modo de funcionamiento: PORTAL (al contacto) o DOOR (por interacción)
@export var mode: Mode = Mode.PORTAL:
	set(value):
		mode = value
		_update_collision_layers()
		_update_visuals()

## Si está activo o deshabilitado por completo (ej. controlado por eventos)
@export var is_active: bool = true:
	set(value):
		is_active = value
		_update_visuals()

@export_group("Cerradura y Llave")
## Si la puerta está bloqueada con candado/llave
@export var is_locked: bool = false:
	set(value):
		is_locked = value
		_update_visuals()

## Objeto/Llave requerida en el Inventario para abrir. Arrastra aquí un ItemData (ej. rusty_key.tres).
@export var key: ItemData:
	set(value):
		key = value
		if key != null:
			is_locked = true
		_update_visuals()

## Si consume la llave del inventario al abrirse
@export var consume_key: bool = false

## Mensaje emergente o texto de diálogo cuando está bloqueada
@export var locked_message: String = "Está cerrada con llave."

## Recurso de diálogo opcional para el bloqueo
@export var locked_dialogue_resource: Resource
@export var locked_dialogue_title: String = "locked"

## ID único para persistencia del estado is_locked / is_active entre cambios de nivel.
@export var persistence_id: String = ""


@export_group("Configuración de Destino")
@export_file("*.tscn") var target_level_path: String = "":
	set(value):
		target_level_path = value
		update_configuration_warnings()

## ID de salida: ID de llegada al que se conectará en el nivel destino
@export var exit_id: String = "":
	set(value):
		exit_id = value
		_update_visuals()
		update_configuration_warnings()

## ID de llegada: Identificador único propio para recibir jugadores que entren a este nivel
@export var arrival_id: String = "":
	set(value):
		arrival_id = value
		_update_visuals()
		update_configuration_warnings()

@export_group("Texturas / Visuales")
## Textura cuando es un portal activo (abierto/vórtice)
@export var portal_active_texture: Texture2D = preload("res://assets/sprites/door_portal_open.svg"):
	set(value):
		portal_active_texture = value
		_update_visuals()

## Textura cuando es una puerta desbloqueada/normal
@export var door_unlocked_texture: Texture2D = preload("res://assets/sprites/door_closed.svg"):
	set(value):
		door_unlocked_texture = value
		_update_visuals()

## Textura cuando está bloqueada o desactivada (candado / rejas)
@export var locked_texture: Texture2D = preload("res://assets/sprites/door_locked.svg"):
	set(value):
		locked_texture = value
		_update_visuals()

@onready var sprite: Sprite2D = $DoorSprite if has_node("DoorSprite") else null
@onready var exit_label: Label = $ExitIdLabel if has_node("ExitIdLabel") else null
@onready var spawn_point_node: Marker2D = $SpawnPoint if has_node("SpawnPoint") else null
@onready var arrival_label: Label = $SpawnPoint/ArrivalIdLabel if has_node("SpawnPoint/ArrivalIdLabel") else null

var _is_triggered: bool = false
var _persistence_key: String = ""

func _ready() -> void:
	_persistence_key = PersistenceIdHelper.runtime_key(self, persistence_id)
	add_to_group("arrival_points")
	_update_collision_layers()
	if not Engine.is_editor_hint():
		if not body_entered.is_connected(_on_body_entered):
			body_entered.connect(_on_body_entered)
		if not body_exited.is_connected(_on_body_exited):
			body_exited.connect(_on_body_exited)
		_set_debug_visibility(ArrivalSpawnPoint.debug_visuals_visible)
		_restore_state()
	_update_visuals()

func _restore_state() -> void:
	if _persistence_key.is_empty():
		return
	var wsm := WorldStateManager
	if not wsm or not wsm.has_state(_persistence_key):
		return
	var data: Dictionary = wsm.load_state(_persistence_key)
	is_locked = data.get("is_locked", is_locked)
	is_active = data.get("is_active", is_active)

func _update_collision_layers() -> void:
	if mode == Mode.DOOR:
		collision_layer = CollisionLayers.ACTIONABLE
		collision_mask = CollisionLayers.PLAYER
		if has_node("SolidBody/SolidCollision"):
			$SolidBody/SolidCollision.set_deferred("disabled", false)
	else:
		collision_layer = 0
		collision_mask = CollisionLayers.PLAYER
		if has_node("SolidBody/SolidCollision"):
			$SolidBody/SolidCollision.set_deferred("disabled", true)

func _unhandled_input(event: InputEvent) -> void:
	ArrivalSpawnPoint.handle_debug_input(self, event)

func _set_debug_visibility(p_visible: bool) -> void:
	if has_node("ExitIdLabel"):
		$ExitIdLabel.visible = p_visible
	if has_node("SpawnPoint/ArrivalIdLabel"):
		$SpawnPoint/ArrivalIdLabel.visible = p_visible

func _update_visuals() -> void:
	if not is_node_ready():
		return
		
	if has_node("DoorSprite"):
		var door_sprite: Sprite2D = $DoorSprite
		if not is_active or is_locked:
			door_sprite.texture = locked_texture
		elif mode == Mode.PORTAL:
			door_sprite.texture = portal_active_texture
		else:
			door_sprite.texture = door_unlocked_texture

	if has_node("ExitIdLabel"):
		$ExitIdLabel.text = exit_id
		if Engine.is_editor_hint():
			$ExitIdLabel.visible = true
	if has_node("SpawnPoint/ArrivalIdLabel"):
		$SpawnPoint/ArrivalIdLabel.text = arrival_id
		if Engine.is_editor_hint():
			$SpawnPoint/ArrivalIdLabel.visible = true

## Invocado por ActionableFinder del Player al pulsar botón de interacción (E / ui_accept)
func action() -> void:
	if mode != Mode.DOOR or _is_triggered:
		return
	_attempt_traverse()

## Invocado por colisión al entrar
func _on_body_entered(body: Node2D) -> void:
	if mode != Mode.PORTAL or _is_triggered or Engine.is_editor_hint():
		return
		
	if body.name == "Player" or body.is_in_group("player"):
		_attempt_traverse()

## Invocado por colisión al salir (reactiva el trigger para re-ingreso)
func _on_body_exited(body: Node2D) -> void:
	if Engine.is_editor_hint():
		return
	if body.name == "Player" or body.is_in_group("player"):
		_is_triggered = false

func _attempt_traverse() -> void:
	if not is_active:
		_show_locked_feedback("La puerta está atrancada y no responde.")
		return
		
	if is_locked:
		if key == null or key.id.is_empty() or not Inventory.has_item_amount(key.id, 1):
			_show_locked_feedback(locked_message)
			return
		
		if consume_key:
			Inventory.remove_item(key.id, 1)
		is_locked = false
		_update_visuals()
		unlocked.emit()
		_persist_state()
		print("[LevelPortal] Puerta desbloqueada con llave '%s' (consumida: %s)" % [key.id, str(consume_key)])

	# Puerta/Portal abierto y listo para viajar
	_trigger_transition()

func _trigger_transition() -> void:
	_is_triggered = true
	portal_triggered.emit(target_level_path, exit_id)
	opened.emit()
	GameManager.change_level(target_level_path, exit_id)

func _show_locked_feedback(msg: String) -> void:
	locked.emit()
	if locked_dialogue_resource:
		DialogueManager.show_dialogue_balloon(locked_dialogue_resource, locked_dialogue_title)
	else:
		print("[LevelPortal Bloqueado]: ", msg)

## Métodos públicos para ser activados por eventos / interruptores
func unlock() -> void:
	is_locked = false
	_update_visuals()
	unlocked.emit()
	_persist_state()

func lock() -> void:
	is_locked = true
	_update_visuals()
	locked.emit()
	_persist_state()

func set_active_state(active: bool) -> void:
	is_active = active
	_persist_state()

func _persist_state() -> void:
	if _persistence_key.is_empty():
		return
	var wsm := WorldStateManager
	if wsm:
		wsm.save_state(_persistence_key, {"is_locked": is_locked, "is_active": is_active})

func get_spawn_position() -> Vector2:
	if has_node("SpawnPoint"):
		return $SpawnPoint.global_position
	return global_position

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if target_level_path.strip_edges().is_empty():
		warnings.append("Debe seleccionar un 'target_level_path' (escena destino).")
	if exit_id.strip_edges().is_empty():
		warnings.append("Debe asignar un 'exit_id' que apunte al arrival_id en el nivel destino.")
	if arrival_id.strip_edges().is_empty():
		warnings.append("Debe asignar un 'arrival_id' único para este portal.")
	else:
		var root_node: Node = ArrivalSpawnPoint.find_scene_root(self)
		if root_node and ArrivalSpawnPoint.count_arrival_id(root_node, arrival_id) > 1:
			warnings.append("Existe otro portal o spawn point con el mismo arrival_id ('%s'). Deben ser únicos." % arrival_id)
	return warnings
