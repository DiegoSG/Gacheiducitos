@tool
extends Area2D
class_name LevelPortal

signal portal_triggered(target_level_path: String, target_arrival_id: String)
signal opened()
signal locked()
signal unlocked()

enum Mode {
	PORTAL, ## Activates automatically when stepping onto the area
	DOOR    ## Activates by interacting with the action button (E / Space / A)
}

@export_group("Access Type")
## Operating mode: PORTAL (on contact) or DOOR (by interaction)
@export var mode: Mode = Mode.PORTAL:
	set(value):
		mode = value
		_update_collision_layers()
		_update_visuals()

## Whether it is active or fully disabled (e.g. controlled by events)
@export var is_active: bool = true:
	set(value):
		is_active = value
		_update_visuals()

## If checked, it cannot be passed while any living enemy (group "enemy") remains in the scene
@export var requires_no_enemies: bool = false:
	set(value):
		requires_no_enemies = value
		_update_visuals()

## Balloon text when trying to pass with living enemies. If empty, the lock text (locked_text) is used.
@export_multiline var enemies_alive_text: String = ""

@export_group("Lock and Key")
## Whether the door is locked with a padlock/key
@export var is_locked: bool = false:
	set(value):
		is_locked = value
		_update_visuals()

## Item/key required in the Inventory to open. Drag an ItemData here (e.g. rusty_key.tres).
@export var key: ItemData:
	set(value):
		key = value
		if key != null:
			is_locked = true
		_update_visuals()

## Whether it consumes the key from the inventory when opened
@export var consume_key: bool = false

## Text shown in the dialogue balloon when trying to pass while closed or inactive.
## Each line is one dialogue step. If a locked_dialogue_resource is assigned, it takes priority.
@export_multiline var locked_text: String = ""

## Optional dialogue resource for the lock (takes priority over locked_text)
@export var locked_dialogue_resource: Resource
@export var locked_dialogue_title: String = "locked"

## Unique ID for persisting the is_locked / is_active state across level changes.
@export var persistence_id: String = ""


@export_group("Destination Settings")
@export_file("*.tscn") var target_level_path: String = "":
	set(value):
		target_level_path = value
		update_configuration_warnings()

## Exit ID: the arrival ID this connects to in the destination level
@export var exit_id: String = "":
	set(value):
		exit_id = value
		_update_visuals()
		update_configuration_warnings()

## Arrival ID: its own unique identifier for receiving players who enter this level
@export var arrival_id: String = "":
	set(value):
		arrival_id = value
		_update_visuals()
		update_configuration_warnings()

@export_group("Textures / Visuals")
## Texture when it is an active portal (open/vortex)
@export var portal_active_texture: Texture2D = preload("res://assets/sprites/door_portal_open.svg"):
	set(value):
		portal_active_texture = value
		_update_visuals()

## Texture when it is an unlocked/normal door
@export var door_unlocked_texture: Texture2D = preload("res://assets/sprites/door_closed.svg"):
	set(value):
		door_unlocked_texture = value
		_update_visuals()

## Texture when locked or disabled (padlock / bars)
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
## Dialogue generated from locked_text (created the first time it is needed)
var _locked_text_resource: Resource = null
## Dialogue generated from enemies_alive_text
var _enemies_text_resource: Resource = null
## Whether the last check found living enemies (to announce when the scene is cleared)
var _enemies_blocking: bool = false

## Words/prefixes that Dialogue Manager interprets as syntax at the start of a line
const _DIALOGUE_SYNTAX_PREFIXES: Array[String] = ["- ", "~", "=>", "=<", "#", "%", "if ", "elif ", "else", "do ", "do! ", "set ", "while ", "match ", "when ", "import ", "using "]

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
		if requires_no_enemies:
			get_tree().node_removed.connect(_on_tree_node_removed)
			# Deferred: enemies register in the group in their own _ready
			call_deferred("_refresh_enemy_block")
	_update_visuals()

func _restore_state() -> void:
	if _persistence_key.is_empty():
		return
	if not WorldStateManager.has_state(_persistence_key):
		return
	var data: Dictionary = WorldStateManager.load_state(_persistence_key)
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
		if not is_active or is_locked or _enemies_blocking:
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

## Called by the Player's ActionableFinder when the interact button is pressed (interact action)
func action() -> void:
	if mode != Mode.DOOR or _is_triggered:
		return
	_attempt_traverse()

## Called by collision when entering
func _on_body_entered(body: Node2D) -> void:
	if mode != Mode.PORTAL or _is_triggered or Engine.is_editor_hint():
		return
		
	if body.name == "Player" or body.is_in_group("player"):
		_attempt_traverse()

## Called by collision when exiting (re-arms the trigger for re-entry)
func _on_body_exited(body: Node2D) -> void:
	if Engine.is_editor_hint():
		return
	if body.name == "Player" or body.is_in_group("player"):
		_is_triggered = false

func _attempt_traverse() -> void:
	if not is_active:
		AudioManager.play_ui(&"sfx_portal_inactive")
		_show_locked_feedback()
		return

	if requires_no_enemies:
		_refresh_enemy_block()
		if _enemies_blocking:
			AudioManager.play_ui(&"sfx_door_locked")
			_show_enemies_feedback()
			return
		
	if is_locked:
		if key == null or key.id.is_empty() or not Inventory.has_item_amount(key.id, 1):
			AudioManager.play_ui(&"sfx_door_locked")
			_show_locked_feedback()
			return
		
		AudioManager.play_sfx(&"sfx_door_unlock_key")
		if consume_key:
			AudioManager.play_sfx(&"sfx_key_used")
			Inventory.remove_item(key.id, 1)
		is_locked = false
		_update_visuals()
		unlocked.emit()
		_persist_state()

	# Door/portal open and ready to travel
	_trigger_transition()

func _trigger_transition() -> void:
	_is_triggered = true
	AudioManager.play_ui(&"sfx_portal_enter")
	portal_triggered.emit(target_level_path, exit_id)
	opened.emit()
	GameManager.change_level(target_level_path, exit_id)

func _show_locked_feedback() -> void:
	locked.emit()
	if locked_dialogue_resource:
		DialogueManager.show_dialogue_balloon(locked_dialogue_resource, locked_dialogue_title)
	elif not locked_text.strip_edges().is_empty():
		if _locked_text_resource == null:
			_locked_text_resource = DialogueManager.create_resource_from_text(_build_dialogue_from_text(locked_text))
		DialogueManager.show_dialogue_balloon(_locked_text_resource, "start")

func _show_enemies_feedback() -> void:
	if enemies_alive_text.strip_edges().is_empty():
		_show_locked_feedback()
		return
	locked.emit()
	if _enemies_text_resource == null:
		_enemies_text_resource = DialogueManager.create_resource_from_text(_build_dialogue_from_text(enemies_alive_text))
	DialogueManager.show_dialogue_balloon(_enemies_text_resource, "start")

## Counts the living enemies in the scene (ones that already died are queued for deletion)
func _count_alive_enemies() -> int:
	var count: int = 0
	for enemy: Node in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy) and enemy.is_inside_tree() and not enemy.is_queued_for_deletion():
			count += 1
	return count

## Recalculates the enemy block; when the scene clears, the unlock sound plays
func _refresh_enemy_block() -> void:
	if not is_inside_tree():
		return
	var was_blocking: bool = _enemies_blocking
	_enemies_blocking = requires_no_enemies and _count_alive_enemies() > 0
	if was_blocking and not _enemies_blocking and is_active and not is_locked:
		AudioManager.play_sfx(&"sfx_door_unlock")
	_update_visuals()

func _on_tree_node_removed(node: Node) -> void:
	# When leaving the tree the node is still in the group: checked deferred
	if node.is_in_group("enemy"):
		call_deferred("_refresh_enemy_block")

## Converts plain text into a single-title dialogue ("start"), escaping the syntax
## of Dialogue Manager so the text is shown literally (no character or options).
func _build_dialogue_from_text(text: String) -> String:
	var out: String = "~ start\n"
	for raw_line: String in text.split("\n", false):
		var line: String = raw_line.strip_edges()
		if line.is_empty():
			continue
		line = line.replace(":", "\\:")
		for prefix: String in _DIALOGUE_SYNTAX_PREFIXES:
			if line.begins_with(prefix):
				# Zero-width space: prevents the line from being interpreted as syntax
				line = "\u200B" + line
				break
		out += line + "\n"
	return out + "=> END\n"

## Public methods to be triggered by events / switches
func unlock() -> void:
	AudioManager.play_sfx(&"sfx_door_unlock")
	is_locked = false
	_update_visuals()
	unlocked.emit()
	_persist_state()

func lock() -> void:
	AudioManager.play_sfx(&"sfx_door_lock")
	is_locked = true
	_update_visuals()
	locked.emit()
	_persist_state()

func set_active_state(active: bool) -> void:
	AudioManager.play_sfx(&"sfx_door_toggle")
	is_active = active
	_persist_state()

func _persist_state() -> void:
	if _persistence_key.is_empty():
		return
	WorldStateManager.save_state(_persistence_key, {"is_locked": is_locked, "is_active": is_active})

## The player arrives through this portal: ignores its contact until they leave the area,
## so the exit walk does not send them back to the previous level.
func begin_arrival() -> void:
	_is_triggered = true

func get_spawn_position() -> Vector2:
	if has_node("SpawnPoint"):
		return $SpawnPoint.global_position
	return global_position

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if target_level_path.strip_edges().is_empty():
		warnings.append("You must select a 'target_level_path' (destination scene).")
	if exit_id.strip_edges().is_empty():
		warnings.append("You must assign an 'exit_id' that points to the arrival_id in the destination level.")
	if arrival_id.strip_edges().is_empty():
		warnings.append("You must assign a unique 'arrival_id' to this portal.")
	else:
		var root_node: Node = ArrivalSpawnPoint.find_scene_root(self)
		if root_node and ArrivalSpawnPoint.count_arrival_id(root_node, arrival_id) > 1:
			warnings.append("Another portal or spawn point has the same arrival_id ('%s'). They must be unique." % arrival_id)
	return warnings
