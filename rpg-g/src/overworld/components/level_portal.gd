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

## ID del ítem requerido en el Inventario para abrir (ej. 'rusty_key'). Si está vacío y 'key' es nulo, se abre sin ítem.
@export var required_key_id: String = ""

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
static var debug_visuals_visible: bool = false

func _ready() -> void:
	add_to_group("arrival_points")
	_update_collision_layers()
	if not Engine.is_editor_hint():
		if not body_entered.is_connected(_on_body_entered):
			body_entered.connect(_on_body_entered)
		if not body_exited.is_connected(_on_body_exited):
			body_exited.connect(_on_body_exited)
		_set_debug_visibility(debug_visuals_visible)
		_restore_state()
	_update_visuals()

func _restore_state() -> void:
	if persistence_id.is_empty():
		return
	var wsm := WorldStateManager
	if not wsm or not wsm.has_state(persistence_id):
		return
	var data: Dictionary = wsm.load_state(persistence_id)
	is_locked = data.get("is_locked", is_locked)
	is_active = data.get("is_active", is_active)

func _update_collision_layers() -> void:
	# Layer 2 es Player (collision_mask = 2 para detectar entrada física)
	# Layer 5 (16) es Actionable (collision_layer = 16 para que ActionableFinder del player lo detecte)
	if mode == Mode.DOOR:
		collision_layer = 16 # Actionable layer
		collision_mask = 2   # Detecta al jugador
		if has_node("SolidBody/SolidCollision"):
			$SolidBody/SolidCollision.set_deferred("disabled", false)
	else:
		collision_layer = 0
		collision_mask = 2   # Solo detecta al jugador por toque
		if has_node("SolidBody/SolidCollision"):
			$SolidBody/SolidCollision.set_deferred("disabled", true)

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			get_viewport().set_input_as_handled()
			toggle_debug_visuals()

func toggle_debug_visuals() -> void:
	debug_visuals_visible = not debug_visuals_visible
	for node in get_tree().get_nodes_in_group("arrival_points"):
		if node.has_method("_set_debug_visibility"):
			node._set_debug_visibility(debug_visuals_visible)

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

func _get_inventory_node() -> Node:
	if Engine.has_singleton("Inventory"):
		return Engine.get_singleton("Inventory")
	var node := Inventory
	if node:
		return node
	if is_inside_tree() and get_tree() and get_tree().root:
		for child in get_tree().root.get_children():
			if child.name == "Inventory" or child.get_script() == preload("res://src/core/inventory.gd"):
				return child
	return null

func _get_effective_key_id() -> String:
	if key and not key.id.is_empty():
		return key.id
	return required_key_id

func _attempt_traverse() -> void:
	if not is_active:
		_show_locked_feedback("La puerta está atrancada y no responde.")
		return
		
	if is_locked:
		var effective_key_id: String = _get_effective_key_id()
		if not effective_key_id.is_empty():
			var inventory = _get_inventory_node()
			var has_key: bool = false
			if inventory and inventory.has_method("get_items"):
				has_key = inventory.get_items().get(effective_key_id, 0) > 0
			
			if has_key:
				if consume_key and inventory:
					inventory.remove_item(effective_key_id, 1)
				is_locked = false
				_update_visuals()
				unlocked.emit()
				_persist_state()
				print("[LevelPortal] Puerta desbloqueada con llave '%s' (consumida: %s)" % [effective_key_id, str(consume_key)])
			else:
				_show_locked_feedback(locked_message)
				return
		else:
			_show_locked_feedback(locked_message)
			return

	# Puerta/Portal abierto y listo para viajar
	_trigger_transition()

func _trigger_transition() -> void:
	_is_triggered = true
	portal_triggered.emit(target_level_path, exit_id)
	opened.emit()
	var game_manager := GameManager
	if game_manager:
		game_manager.change_level(target_level_path, exit_id)

func _show_locked_feedback(msg: String) -> void:
	locked.emit()
	var dm = get_node_or_null("/root/DialogueManager")
	if not dm and Engine.has_singleton("DialogueManager"):
		dm = Engine.get_singleton("DialogueManager")
	if locked_dialogue_resource and dm:
		dm.show_dialogue_balloon(locked_dialogue_resource, locked_dialogue_title)
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
	if persistence_id.is_empty():
		return
	var wsm := WorldStateManager
	if wsm:
		wsm.save_state(persistence_id, {"is_locked": is_locked, "is_active": is_active})

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
		var root_node: Node = null
		if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
			root_node = get_tree().edited_scene_root
		elif get_owner():
			root_node = get_owner()
		elif get_parent():
			root_node = get_parent()
			while root_node.get_parent() and not (root_node.get_parent() is Window):
				root_node = root_node.get_parent()
				
		if root_node:
			var duplicates = _find_duplicate_arrival_ids(root_node, arrival_id)
			if duplicates > 1:
				warnings.append("Existe otro portal o spawn point con el mismo arrival_id ('%s'). Deben ser únicos." % arrival_id)
	return warnings

func _find_duplicate_arrival_ids(node: Node, target_id: String) -> int:
	var count: int = 0
	if "arrival_id" in node and node.arrival_id == target_id:
		count += 1
	for child in node.get_children():
		count += _find_duplicate_arrival_ids(child, target_id)
	return count
