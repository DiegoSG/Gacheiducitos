extends Node

# Singleton to manage game state and scene transitions

signal level_changed(target_level_path: String, spawn_id: String)
signal game_event(event_name: String, event_data: Variant)

const FADER_SCENE: PackedScene = preload("res://src/ui/screen_fader.tscn")
const DEFAULT_LEVEL_PATH: String = "res://src/overworld/levels/level_01.tscn"
## Duration (s) of the automatic walk from the portal to its arrival point.
const PORTAL_EXIT_TIME: float = 0.35

var current_scene: Node = null
var previous_scene_path: String = ""

# Minigame configuration (for debug and persistence)
var minigame_config: Dictionary = {}
var current_level_seed: int = -1

var _minigame_win_path: String = ""
var _minigame_win_spawn_id: String = ""
var _minigame_lose_path: String = ""
var _minigame_lose_spawn_id: String = ""
var _is_changing_level: bool = false

# Shared pause: each system that needs to freeze the game (inventory, dialogues...)
# requests a pause and releases it; the game only resumes when nobody needs it.
var _pause_requests: int = 0
var _dialogue_pause_active: bool = false


func _ready() -> void:
	# Dialogues pause the world (enemies, timers, poison...); the dialogue manager
	# must keep processing in the meantime.
	DialogueManager.process_mode = Node.PROCESS_MODE_ALWAYS
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

	var root: Window = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)
	if is_instance_valid(current_scene):
		# Allows running a standalone minigame (F6) and still granting its rewards
		_connect_minigame_finished(current_scene)
		CheckpointManager.register_level_entry(current_scene.scene_file_path, current_scene, false)

## Freezes the game. Each call must have its matching release_pause().
func request_pause() -> void:
	_pause_requests += 1
	_set_paused(true)

## Releases a pause request; the game resumes when none remain.
func release_pause() -> void:
	_pause_requests = maxi(0, _pause_requests - 1)
	if _pause_requests == 0:
		_set_paused(false)

## Cancels all pending pauses (on scene change, the UIs that requested them disappear).
func _reset_pause() -> void:
	_pause_requests = 0
	_dialogue_pause_active = false
	_set_paused(false)

func _set_paused(paused: bool) -> void:
	if get_tree().paused == paused:
		return
	get_tree().paused = paused
	AudioManager.play_ui(&"sfx_game_paused" if paused else &"sfx_game_resumed")

func _on_dialogue_started(_resource: DialogueResource) -> void:
	if not _dialogue_pause_active:
		_dialogue_pause_active = true
		request_pause()

func _on_dialogue_ended(_resource: DialogueResource) -> void:
	AudioManager.play_ui(&"sfx_dialogue_close")
	if _dialogue_pause_active:
		_dialogue_pause_active = false
		release_pause()

func trigger_event(event_name: String, event_data: Variant = null) -> void:
	game_event.emit(event_name, event_data)

## Loads a minigame with a transition (fade). Saves the previous scene and the return paths
## defined in minigame_config.
func load_minigame(minigame_path: String) -> void:
	if minigame_path.is_empty():
		push_error("GameManager: Cannot load empty minigame path.")
		return

	# Only save the previous scene if it is NOT already part of a minigame run
	# (so that test scenes or the Overworld are preserved correctly)
	if is_instance_valid(current_scene) and not (current_scene is MinigameBase):
		previous_scene_path = current_scene.scene_file_path

	# Take return paths from the config if they exist, otherwise use the previous scene
	_minigame_win_path = minigame_config.get("win_level_path", previous_scene_path)
	_minigame_win_spawn_id = minigame_config.get("win_spawn_id", "")
	_minigame_lose_path = minigame_config.get("lose_level_path", previous_scene_path)
	_minigame_lose_spawn_id = minigame_config.get("lose_spawn_id", "")

	AudioManager.play_ui(&"sfx_minigame_enter")
	change_level(minigame_path)

func complete_minigame(success: bool, results: Dictionary = {}) -> void:
	# Grant rewards (gold is routed to PlayerStats by Inventory.add_item on its own)
	var pending_items: Dictionary = {}
	if results.has("items"):
		pending_items = results["items"] as Dictionary
		for item_id: String in pending_items:
			Inventory.add_item(item_id, int(pending_items[item_id]))
			
	# Decide where to go and which spawn to use
	var target_scene: String = _minigame_win_path if success else _minigame_lose_path
	var target_spawn_id: String = _minigame_win_spawn_id if success else _minigame_lose_spawn_id
	
	# Fallback in case they are empty for some reason
	if target_scene.is_empty():
		target_scene = previous_scene_path if not previous_scene_path.is_empty() else DEFAULT_LEVEL_PATH
		
	AudioManager.play_ui(&"sfx_minigame_return")
	# Use the fader transition system
	await change_level(target_scene, target_spawn_id)
	
	# If we got items from the minigame, show their arrival
	if not pending_items.is_empty():
		AudioManager.play_ui(&"sfx_minigame_rewards")
	for item_id: String in pending_items:
		var data: ItemData = ItemDatabase.get_item(item_id)
		if data:
			LootFeedbackManager.trigger_toast(data, int(pending_items[item_id]))

func return_to_overworld() -> void:
	var target_scene: String = previous_scene_path if not previous_scene_path.is_empty() else DEFAULT_LEVEL_PATH
	change_level(target_scene)

# Connects game_finished of a MinigameBase to complete_minigame (the only source of this connection)
func _connect_minigame_finished(scene: Node) -> void:
	if scene is MinigameBase:
		var minigame: MinigameBase = scene as MinigameBase
		if not minigame.game_finished.is_connected(complete_minigame):
			minigame.game_finished.connect(complete_minigame)

func change_level(target_level_path: String, spawn_id: String = "", exact_pos: Vector2 = Vector2.ZERO, use_exact: bool = false, is_save_load: bool = false) -> void:
	if _is_changing_level:
		return
	if target_level_path.is_empty():
		return

	_is_changing_level = true
	AudioManager.play_ui(&"sfx_level_change")
	_reset_pause()
	
	if not is_save_load:
		WorldStateManager.clear_ephemeral_states()
		
	var fader: ScreenFader = FADER_SCENE.instantiate()
	get_tree().root.add_child(fader)
	
	# Disable player movement if it exists
	if is_instance_valid(current_scene) and current_scene.has_node("Player"):
		current_scene.get_node("Player").set_physics_process(false)
		
	await fader.fade_out(0.4)

	var next_scene_resource: PackedScene = ResourceLoader.load(target_level_path) as PackedScene
	if not next_scene_resource:
		push_error("GameManager: Failed to load target level: %s" % target_level_path)
		await fader.fade_in(0.2)
		fader.queue_free()
		_is_changing_level = false
		if is_instance_valid(current_scene) and current_scene.has_node("Player"):
			current_scene.get_node("Player").set_physics_process(true)
		return

	if is_instance_valid(current_scene):
		current_scene.queue_free()
		await get_tree().process_frame
		
	AlertSystem.clear_pursuers()
	current_scene = next_scene_resource.instantiate()
	get_tree().root.add_child(current_scene)
	get_tree().current_scene = current_scene
	_connect_minigame_finished(current_scene)
	
	# Position the player at the desired spawn
	var player: Node2D = null
	# Exit walk destination when arriving through a portal with a SpawnPoint.
	var exit_walk_target: Vector2 = Vector2.ZERO
	var has_exit_walk: bool = false
	if current_scene.has_node("Player"):
		player = current_scene.get_node("Player") as Node2D
		if use_exact:
			player.global_position = exact_pos
		elif not spawn_id.is_empty():
			var found_spawn: bool = false
			# 1. Search nodes in the arrival_points group (LevelPortal and ArrivalSpawnPoint) within the new scene
			for arrival_node in get_tree().get_nodes_in_group("arrival_points"):
				if is_instance_valid(arrival_node) and current_scene.is_ancestor_of(arrival_node):
					if "arrival_id" in arrival_node and str(arrival_node.arrival_id) == str(spawn_id):
						if arrival_node is LevelPortal and arrival_node.global_position.distance_to(arrival_node.get_spawn_position()) > 1.0:
							# Appears at the portal and walks to the arrival point (see below)
							arrival_node.begin_arrival()
							exit_walk_target = arrival_node.get_spawn_position()
							has_exit_walk = true
							player.global_position = arrival_node.global_position
						elif arrival_node.has_method("get_spawn_position"):
							player.global_position = arrival_node.get_spawn_position()
						else:
							player.global_position = arrival_node.global_position
						found_spawn = true
						break
			# 2. Compatibility fallback for legacy scenes (SpawnPoints/ID)
			if not found_spawn and current_scene.has_node("SpawnPoints/" + spawn_id):
				var spawn_node: Node2D = current_scene.get_node("SpawnPoints/" + spawn_id) as Node2D
				player.global_position = spawn_node.global_position
				found_spawn = true
				
		# Reposition and reset camera smoothing before the fade in
		_snap_scene_cameras(current_scene)
		if not has_exit_walk:
			player.set_physics_process(true)
		
	# Wait one frame to settle transforms and camera limits before clearing the screen
	await get_tree().process_frame
		
	await fader.fade_in(0.4)
	fader.queue_free()
	if has_exit_walk and is_instance_valid(player):
		await _play_portal_exit(player, exit_walk_target)
	_is_changing_level = false
	CheckpointManager.register_level_entry(target_level_path, current_scene, not is_save_load)
	AudioManager.play_ui(&"sfx_level_loaded")
	level_changed.emit(target_level_path, spawn_id)

## Moves the player from the portal to its arrival point and returns control to them.
func _play_portal_exit(player: Node2D, target: Vector2) -> void:
	if player.has_method("face_direction"):
		player.face_direction(player.global_position.direction_to(target))
	var tween: Tween = player.create_tween()
	tween.tween_property(player, "global_position", target, PORTAL_EXIT_TIME)
	await tween.finished
	if is_instance_valid(player):
		player.set_physics_process(true)

func _snap_scene_cameras(node: Node) -> void:
	if node is Camera2D:
		if node.has_method("snap_to_target"):
			node.snap_to_target()
		else:
			node.reset_smoothing()
			node.force_update_scroll()
	for child in node.get_children():
		_snap_scene_cameras(child)
