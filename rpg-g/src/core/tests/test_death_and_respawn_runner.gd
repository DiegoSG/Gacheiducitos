extends SceneTree

## Automated test runner for the Death System, Checkpoints, Snapshots and Respawn.

var _passed_count: int = 0
var _failed_count: int = 0
var _died_emitted: bool = false

func _on_player_died_test() -> void:
	_died_emitted = true

func _init() -> void:
	print("\n===========================================================")
	print("--- TEST RUNNER: DEATH, CHECKPOINT, SNAPSHOTS & RESPAWN ---")
	print("===========================================================\n")

	await process_frame

	# 1. Get the official Autoloads already instantiated by the Engine
	var inventory: Node = root.get_node("Inventory")
	var player_stats: Node = root.get_node("PlayerStats")
	var world_state: Node = root.get_node("WorldStateManager")
	var gm: Node = root.get_node("GameManager")

	# ========================================================
	# TEST 1: player_died signal in PlayerStats when reaching 0 HP
	# ========================================================
	player_stats.max_health = 100
	player_stats.health = 50
	_died_emitted = false
	player_stats.player_died.connect(_on_player_died_test)
	
	player_stats.take_damage(20)
	_record_result("PlayerStats: take_damage subtracts HP without emitting death early", player_stats.health == 30 and not _died_emitted)

	player_stats.take_damage(30)
	_record_result("PlayerStats: Reaching 0 HP emits player_died", player_stats.health == 0 and _died_emitted)

	# ========================================================
	# TEST 2: Snapshots and Restoration of PlayerStats and Inventory
	# ========================================================
	player_stats.player_died.disconnect(_on_player_died_test)
	player_stats.health = 80
	player_stats.gold = 150
	inventory.items = { "red_potion": 3, "iron_key": 1 }
	
	var stats_snap: Dictionary = player_stats.create_snapshot()
	var inv_snap: Dictionary = inventory.create_snapshot()
	
	# Simulate changes made in a later level
	player_stats.health = 10
	player_stats.gold = 30
	inventory.items = { "red_potion": 1, "diamond": 5 }
	
	player_stats.restore_snapshot(stats_snap)
	inventory.restore_snapshot(inv_snap)
	
	var stats_restored: bool = (player_stats.health == 80 and player_stats.gold == 150)
	var inv_restored: bool = (inventory.get_item_count("red_potion") == 3 and inventory.get_item_count("iron_key") == 1 and inventory.get_item_count("diamond") == 0)
	_record_result("PlayerStats: restore_snapshot restores exact HP and Gold", stats_restored)
	_record_result("Inventory: restore_snapshot restores exact inventory", inv_restored)

	# ========================================================
	# TEST 3: Snapshots and Reversion of WorldStateManager
	# ========================================================
	world_state.clear_all()
	world_state.save_state("chest_lvl1_01", {"opened": true})
	world_state.save_state("door_lvl1_01", {"unlocked": true})
	
	var ws_snap: Dictionary = world_state.create_snapshot()
	
	# Changes made in level 2 before dying
	world_state.save_state("chest_lvl2_99", {"opened": true})
	world_state.save_state("enemy_boss_lvl2", {"defeated": true})
	
	_record_result("WorldStateManager: Temporary changes recorded in level 2", world_state.has_state("chest_lvl2_99"))

	# Revert snapshot to the start of level 2
	world_state.restore_snapshot(ws_snap)
	var ws_reverted: bool = (not world_state.has_state("chest_lvl2_99") and not world_state.has_state("enemy_boss_lvl2") and world_state.has_state("chest_lvl1_01"))
	_record_result("WorldStateManager: restore_snapshot reverts the state of the level where the player died without affecting earlier levels", ws_reverted)

	# ========================================================
	# TEST 4: Checkpoint registration and Respawn in GameManager
	# ========================================================
	# Create a mock node for level 1 with an ArrivalSpawnPoint "RespawnPoint"
	var level1: Node2D = Node2D.new()
	level1.name = "Level1Checkpoint"
	level1.scene_file_path = "res://src/overworld/levels/mock_checkpoint_level.tscn"
	
	var respawn_marker: Marker2D = Marker2D.new()
	respawn_marker.name = "RespawnMarker"
	respawn_marker.add_to_group("arrival_points")
	respawn_marker.set("arrival_id", "RespawnPoint")
	respawn_marker.position = Vector2(100, 200)
	level1.add_child(respawn_marker)
	
	root.add_child(level1)
	
	# Set state at Checkpoint
	player_stats.health = 100
	player_stats.gold = 500
	inventory.items = { "ancient_map": 1 }
	
	CheckpointManager.register_level_entry(level1.scene_file_path, level1)
	_record_result("CheckpointManager: Sets active_checkpoint_scene_path when registering entry into a level", CheckpointManager.active_checkpoint_scene_path == level1.scene_file_path)
	
	# Enter Level 2 (not a checkpoint)
	var level2: Node2D = Node2D.new()
	level2.name = "Level2Danger"
	level2.scene_file_path = "res://src/overworld/levels/level_01.tscn"
	root.add_child(level2)
	
	# When ENTERING level 2, the entry is registered and the persistence snapshot is taken
	CheckpointManager.register_level_entry(level2.scene_file_path, level2)
	_record_result("CheckpointManager: Active checkpoint is still Level 1 after entering Level 2", CheckpointManager.active_checkpoint_scene_path == level1.scene_file_path)

	# INSIDE level 2, the player takes damage, spends gold, picks up an item and modifies the world
	player_stats.health = 20
	player_stats.gold = 100
	inventory.items["gem"] = 1
	world_state.save_state("lvl2_item_picked", {"picked": true})
	
	# Simulate the player's respawn after dying in level 2
	gm.current_scene = level2
	await CheckpointManager.respawn_player()
	
	var respawn_stats_ok: bool = (player_stats.health == 100 and player_stats.gold == 500)
	var respawn_inv_ok: bool = (inventory.get_item_count("ancient_map") == 1 and inventory.get_item_count("gem") == 0)
	var respawn_ws_ok: bool = not world_state.has_state("lvl2_item_picked")
	
	_record_result("CheckpointManager.respawn_player: Restores stats from the active checkpoint", respawn_stats_ok)
	_record_result("CheckpointManager.respawn_player: Restores inventory from the active checkpoint", respawn_inv_ok)
	_record_result("CheckpointManager.respawn_player: Reverts persistence of level 2", respawn_ws_ok)

	# ====================================================
	# FINAL SUMMARY
	# ====================================================
	print("\n-------------------------------------------------------")
	print("FINAL RESULTS:")
	print("  Tests passed: ", _passed_count)
	print("  Tests failed: ", _failed_count)
	print("-------------------------------------------------------")

	level1.queue_free()
	level2.queue_free()

	if _failed_count == 0:
		print("\n>>> ALL DEATH, CHECKPOINT AND RESPAWN TESTS PASSED AT 100% <<<\n")
		quit(0)
	else:
		push_error("Failures detected in the respawn test suite.")
		quit(1)

func _record_result(test_name: String, success: bool, extra_info: String = "") -> void:
	if success:
		_passed_count += 1
		print("[PASS] %s" % test_name)
	else:
		_failed_count += 1
		var err_msg = "[FAIL] %s" % test_name
		if not extra_info.is_empty():
			err_msg += " -> " + extra_info
		push_error(err_msg)
		print(err_msg)
