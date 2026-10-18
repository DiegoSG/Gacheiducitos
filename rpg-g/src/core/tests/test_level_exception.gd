extends Node

## Unit and integration test for the Autosave Exception (LevelExceptionConfig)
## and the registration of active_checkpoint_spawn_id in CheckpointManager.

var _autosave_count: int = 0
var _passed_count: int = 0
var _failed_count: int = 0

func _on_game_saved(slot_id: int) -> void:
	var ss = get_node_or_null("/root/SaveSystem")
	if ss and slot_id == ss.AUTOSAVE_SLOT_ID:
		_autosave_count += 1

func _record_result(test_name: String, condition: bool) -> void:
	if condition:
		_passed_count += 1
		print("[PASS] ", test_name)
	else:
		_failed_count += 1
		printerr("[FAIL] ", test_name)

func _ready() -> void:
	print("\n=======================================================")
	print("--- TEST RUNNER: AUTOSAVE EXCEPTION & RESPAWN SPAWN ID ---")
	print("=======================================================\n")
	
	await get_tree().process_frame
	
	var ss = get_node_or_null("/root/SaveSystem")
	var cm = get_node_or_null("/root/CheckpointManager")
	var gm = get_node_or_null("/root/GameManager")
	
	assert(ss != null, "SaveSystem must exist as an Autoload")
	assert(cm != null, "CheckpointManager must exist as an Autoload")
	
	ss.game_saved.connect(_on_game_saved)
	
	# Make sure GameManager has a valid scene to allow saving, if applicable
	if gm and not is_instance_valid(gm.current_scene):
		gm.current_scene = self
	
	# -------------------------------------------------------------
	# TEST 1: Standard level (no exception) runs autosave on an organic transition
	# -------------------------------------------------------------
	var standard_level := Node2D.new()
	standard_level.name = "StandardLevel"
	standard_level.scene_file_path = "res://src/overworld/levels/level_01.tscn"
	add_child(standard_level)
	
	_autosave_count = 0
	cm.active_checkpoint_scene_path = ""
	cm.active_checkpoint_spawn_id = ""
	
	cm.register_level_entry(standard_level.scene_file_path, standard_level, true)
	
	_record_result("Standard level: records active_checkpoint_scene_path normally", cm.active_checkpoint_scene_path == standard_level.scene_file_path)
	_record_result("Standard level: active_checkpoint_spawn_id stays empty", cm.active_checkpoint_spawn_id == "")
	_record_result("Standard level: runs organic autosave (slot 0)", _autosave_count == 1)
	
	# -------------------------------------------------------------
	# TEST 2: Level with LevelExceptionConfig (disable_autosave = true)
	#         must SKIP autosave and save respawn_level_path and respawn_spawn_id
	# -------------------------------------------------------------
	var exception_level := Node2D.new()
	exception_level.name = "BossDangerRoom"
	exception_level.scene_file_path = "res://src/overworld/levels/BossRoom.tscn"
	
	var exception_config := LevelExceptionConfig.new()
	exception_config.name = "LevelExceptionConfig"
	exception_config.disable_autosave = true
	exception_config.respawn_level_path = "res://src/overworld/levels/level_01.tscn"
	exception_config.respawn_spawn_id = "BossDoorEntrance"
	exception_level.add_child(exception_config)
	add_child(exception_level)
	
	_autosave_count = 0
	cm.register_level_entry(exception_level.scene_file_path, exception_level, true)
	
	_record_result("Exception active: autosave is skipped", _autosave_count == 0)
	_record_result("Exception active: active_checkpoint_scene_path updated to respawn_level_path", cm.active_checkpoint_scene_path == "res://src/overworld/levels/level_01.tscn")
	_record_result("Exception active: active_checkpoint_spawn_id recorded correctly", cm.active_checkpoint_spawn_id == "BossDoorEntrance")
	
	# -------------------------------------------------------------
	# TEST 3: Level with LevelExceptionConfig but disable_autosave = false
	#         must allow autosave and record the spawn_id
	# -------------------------------------------------------------
	var allowed_level := Node2D.new()
	allowed_level.name = "SubHubRoom"
	allowed_level.scene_file_path = "res://src/overworld/levels/SubHub.tscn"
	
	var allowed_config := LevelExceptionConfig.new()
	allowed_config.name = "LevelExceptionConfig"
	allowed_config.disable_autosave = false
	allowed_config.respawn_level_path = "res://src/overworld/levels/level_02.tscn"
	allowed_config.respawn_spawn_id = "SubHubSpawn"
	allowed_level.add_child(allowed_config)
	add_child(allowed_level)
	
	_autosave_count = 0
	cm.register_level_entry(allowed_level.scene_file_path, allowed_level, true)
	
	_record_result("Exception with disable_autosave=false: runs autosave", _autosave_count == 1)
	_record_result("Exception with disable_autosave=false: active_checkpoint_scene_path updated", cm.active_checkpoint_scene_path == "res://src/overworld/levels/level_02.tscn")
	_record_result("Exception with disable_autosave=false: active_checkpoint_spawn_id recorded", cm.active_checkpoint_spawn_id == "SubHubSpawn")
	
	# -------------------------------------------------------------
	# TEST 4: Non-organic transition (loading a save) must not autosave
	# -------------------------------------------------------------
	var non_organic_level := Node2D.new()
	non_organic_level.name = "LoadedLevel"
	non_organic_level.scene_file_path = "res://src/overworld/levels/level_03.tscn"
	add_child(non_organic_level)
	
	_autosave_count = 0
	cm.register_level_entry(non_organic_level.scene_file_path, non_organic_level, false)
	_record_result("Non-organic transition: does not run autosave", _autosave_count == 0)
	
	# Clean up nodes created for the test
	standard_level.queue_free()
	exception_level.queue_free()
	allowed_level.queue_free()
	non_organic_level.queue_free()
	
	print("\n-------------------------------------------------------")
	print("TEST RESULTS: ", _passed_count, " PASSED, ", _failed_count, " FAILED")
	print("-------------------------------------------------------\n")
	
	if _failed_count > 0:
		push_error("[TestRunner] There were test failures.")
		get_tree().quit(1)
	else:
		print("[TestRunner] All tests passed successfully.")
		get_tree().quit(0)
