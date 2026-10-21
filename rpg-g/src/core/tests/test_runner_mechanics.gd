extends SceneTree

const PlayerScript = preload("res://src/minigames/mg_runner/mg_runner_player.gd")
const PickupScript = preload("res://src/minigames/mg_runner/mg_runner_pickup.gd")

func _init() -> void:
	print("\n--- TEST: RUNNER 2D MECHANICS (SIDE-SCROLLER) ---")
	
	# 1. Ensure autoloads
	var inventory = root.get_node_or_null("Inventory")
	if not inventory:
		var inv_script = load("res://src/core/inventory.gd")
		inventory = inv_script.new()
		inventory.name = "Inventory"
		root.add_child(inventory)
		
	var game_manager = root.get_node_or_null("GameManager")
	if not game_manager:
		var gm_script = load("res://src/core/game_manager.gd")
		game_manager = gm_script.new()
		game_manager.name = "GameManager"
		root.add_child(game_manager)

	await process_frame

	# 2. Load RunnerLevel scene
	var runner_scene = load("res://src/minigames/mg_runner/mg_runner_level.tscn")
	assert(runner_scene != null, "mg_runner_level.tscn must exist and load")
	var level = runner_scene.instantiate()
	root.add_child(level)
	await process_frame

	assert(level is MinigameBase, "RunnerLevel must inherit from MinigameBase")
	print("[PASS] RunnerLevel instantiated and identified as MinigameBase.")

	# 3. Validate Player and standing vs ducking collision states
	var player = level.get_node_or_null("RunnerPlayer")
	assert(player != null, "RunnerPlayer must exist in the level")
	assert(player.stand_collision.disabled == false, "StandCollision must be active when standing")
	assert(player.duck_collision.disabled == true, "DuckCollision must be disabled when standing")
	print("[PASS] RunnerPlayer starts in RUNNING state with the standing collider active.")

	# Simulate ducking
	player._set_ducking_state()
	assert(player.stand_collision.disabled == true, "StandCollision must be disabled when ducking")
	assert(player.duck_collision.disabled == false, "DuckCollision must be enabled when ducking")
	print("[PASS] RunnerPlayer cleanly switches colliders when ducking.")

	# Restore standing
	player._set_standing_state()
	assert(player.stand_collision.disabled == false, "StandCollision active after standing up")
	assert(player.duck_collision.disabled == true, "DuckCollision disabled after standing up")
	print("[PASS] RunnerPlayer correctly restores the standing collider.")

	# Validate jump execution
	player.try_jump()
	assert(player.state == player.State.JUMPING, "The player must be in JUMPING state after jumping")
	assert(player.velocity_y == player.jump_velocity, "velocity_y must match jump_velocity")
	print("[PASS] Direct jump execution (try_jump) validated.")

	# 4. Validate coin patterns
	var world_objects = level.get_node_or_null("WorldObjects")
	assert(world_objects != null, "WorldObjects must exist")
	
	# Test V_INVERTED pattern (jump arc)
	var count_before = world_objects.get_child_count()
	level._spawn_coin_pattern(level.CoinPattern.V_INVERTED, 1000.0)
	var spawned_v_inv = world_objects.get_child_count() - count_before
	assert(spawned_v_inv == 5, "V_INVERTED must generate exactly 5 coins in an arc (got: %d)" % spawned_v_inv)
	print("[PASS] V_INVERTED pattern correctly generates the 5 parabolic coins.")

	# Test LINE_4 pattern
	count_before = world_objects.get_child_count()
	level._spawn_coin_pattern(level.CoinPattern.LINE_4, 1000.0)
	var spawned_line_4 = world_objects.get_child_count() - count_before
	assert(spawned_line_4 == 4, "LINE_4 must generate 4 coins (got: %d)" % spawned_line_4)
	print("[PASS] LINE_4 pattern correctly generates 4 coins in a line.")

	# Test V_SHAPE pattern
	count_before = world_objects.get_child_count()
	level._spawn_coin_pattern(level.CoinPattern.V_SHAPE, 1000.0)
	var spawned_v = world_objects.get_child_count() - count_before
	assert(spawned_v == 5, "V_SHAPE must generate 5 coins (got: %d)" % spawned_v)
	print("[PASS] V_SHAPE pattern correctly generates 5 coins in a V.")

	# 5. Test coin and item collection into the reward buffer
	var initial_coins = level.coins_collected
	var test_coin = load("res://src/minigames/mg_runner/mg_runner_pickup.tscn").instantiate()
	test_coin.pickup_type = PickupScript.PickupType.COIN
	test_coin.item_id = "gold_coins"
	level.world_objects.add_child(test_coin)
	level._on_coin_collected(test_coin)
	assert(level.coins_collected == initial_coins + 1, "coins_collected must increment")
	assert(level.session_rewards.get("gold_coins") >= 1, "gold_coins must accumulate in session_rewards")
	print("[PASS] Coin collection increments the counter and accumulates in session_rewards.")

	# Test random item collection
	var test_item = load("res://src/minigames/mg_runner/mg_runner_pickup.tscn").instantiate()
	test_item.pickup_type = PickupScript.PickupType.RANDOM_ITEM
	test_item.item_id = "blue_potion"
	test_item.amount = 2
	level.world_objects.add_child(test_item)
	level._on_random_item_collected(test_item)
	assert(level.session_rewards.get("blue_potion") == 2, "blue_potion x2 must accumulate in session_rewards")
	print("[PASS] Random item collection adds the item to the session buffer.")

	# 6. Test Win Condition: Distance mode
	level.win_condition = level.WinCondition.DISTANCE
	level.target_value = 50.0
	level.current_distance = 60.0
	var win_detected = [false]
	level.game_finished.connect(func(s: bool, _r: Dictionary): if s: win_detected[0] = true)
	level._check_win_by_distance()
	assert(win_detected[0] == true, "Reaching the goal distance must trigger the win")
	print("[PASS] Distance win condition validated successfully.")

	# 7. Test Win Condition: Key Object mode
	level.queue_free()
	await process_frame
	
	level = runner_scene.instantiate()
	level.win_condition = level.WinCondition.OBJECT
	level.target_item_id = "ancient_map"
	level.target_distance_range = Vector2(10.0, 20.0)
	root.add_child(level)
	await process_frame

	level.current_distance = 25.0
	level._check_spawn_target_object()
	assert(level.target_object_spawned == true, "The goal object must spawn once the range is passed")
	
	# Find the goal pickup
	var found_target_pickup = null
	for child in level.world_objects.get_children():
		if child is PickupScript and child.is_victory_target:
			found_target_pickup = child
			break
	assert(found_target_pickup != null, "A MG_RunnerPickup with is_victory_target = true must exist")
	assert(found_target_pickup.item_id == "ancient_map", "item_id must match target_item_id")
	print("[PASS] Key win object spawns in the world with correct properties and visuals.")

	# Simulate capturing the goal object
	var object_win = [false]
	level.game_finished.connect(func(s: bool, _r: Dictionary): if s: object_win[0] = true)
	level._on_target_pickup_collected(found_target_pickup)
	assert(object_win[0] == true, "Collecting the goal object must complete the game with a win")
	assert(level.session_rewards.get("ancient_map") == 1, "ancient_map must be in session_rewards")
	print("[PASS] Capturing the key object grants the reward and ends in a win.")

	# Clean up
	level.queue_free()
	print("\n>>> ALL RUNNER 2D MECHANICS TESTS PASSED SUCCESSFULLY (100%) <<<\n")
	quit(0)
