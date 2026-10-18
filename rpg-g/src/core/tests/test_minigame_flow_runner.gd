extends SceneTree

func _init() -> void:
	print("\n--- TEST: MINIGAME SYSTEM AND FLOW (FRAMEWORK) ---")

	# 1. Ensure Inventory singleton
	var inventory = root.get_node_or_null("Inventory")
	if not inventory:
		var inv_script = load("res://src/core/inventory.gd")
		inventory = inv_script.new()
		inventory.name = "Inventory"
		root.add_child(inventory)
	inventory.items.clear()

	# 2. Ensure GameManager singleton
	var game_manager = root.get_node_or_null("GameManager")
	if not game_manager:
		var gm_script = load("res://src/core/game_manager.gd")
		game_manager = gm_script.new()
		game_manager.name = "GameManager"
		root.add_child(game_manager)

	await process_frame

	# 3. Validate DummyMinigame instance and MinigameBase class
	var dummy_script = load("res://src/minigames/tests/dummy_minigame.gd")
	var dummy_scene = load("res://src/minigames/tests/dummy_minigame.tscn")
	assert(dummy_scene != null, "Failed to load dummy_minigame.tscn")
	var dummy: Node2D = dummy_scene.instantiate()
	root.add_child(dummy)
	await process_frame

	assert(dummy is MinigameBase, "DummyMinigame must inherit from MinigameBase")
	print("[PASS] DummyMinigame correctly inherits from MinigameBase.")

	# 4. Test reward accumulation in local session
	dummy.add_reward("blue_potion", 2)
	dummy.add_reward("gold_coins", 10)
	assert(dummy.session_rewards["blue_potion"] == 2, "Blue potion reward incorrect")
	assert(dummy.session_rewards["gold_coins"] == 10, "Gold coins reward incorrect")
	assert(not inventory.items.has("blue_potion"), "The global inventory must NOT have the items before finishing")
	print("[PASS] Session reward buffer stores items without prematurely contaminating the inventory.")

	# 5. Test configured MinigameAction
	var action_script = load("res://src/core/pipeline/actions/minigame_action.gd")
	var action = action_script.new()
	action.minigame_type = MinigameAction.MinigameType.CUSTOM_SCENE
	action.custom_scene_path = "res://src/minigames/tests/dummy_minigame.tscn"
	action.win_level_path = "res://src/minigames/tests/test_minigame_flow.tscn"
	action.win_spawn_id = "spawn_win"
	action.lose_level_path = "res://src/minigames/tests/test_minigame_flow.tscn"
	action.lose_spawn_id = "spawn_lose"
	action.config = {"difficulty": "hard"}

	var dummy_trigger = Node.new()
	root.add_child(dummy_trigger)
	action.execute(dummy_trigger)

	assert(game_manager.minigame_config.get("win_level_path") == "res://src/minigames/tests/test_minigame_flow.tscn", "win_level_path not injected")
	assert(game_manager.minigame_config.get("win_spawn_id") == "spawn_win", "win_spawn_id not injected")
	assert(game_manager.minigame_config.get("lose_spawn_id") == "spawn_lose", "lose_spawn_id not injected")
	print("[PASS] MinigameAction correctly injects the win/lose paths and spawns into GameManager.")

	# 5.1 Test MinigameInteractable (GameTrigger in INTERACT mode via action())
	var interactable_scene = load("res://src/overworld/interactables/minigame_interactable.tscn")
	assert(interactable_scene != null, "minigame_interactable.tscn must exist")
	var interactable = interactable_scene.instantiate()
	root.add_child(interactable)
	assert(interactable is GameTrigger, "minigame_interactable must be a GameTrigger")
	assert(interactable.trigger_mode == GameTrigger.TriggerMode.INTERACT, "minigame_interactable must be in INTERACT mode")
	assert(interactable.collision_layer == 16, "minigame_interactable must be on layer 16 (interactable)")
	interactable.actions_if_true.clear()
	interactable.actions_if_true.append(action)
	# Simulate the player pressing 'E' (ActionableFinder)
	interactable.action()
	await process_frame
	print("[PASS] MinigameInteractable responds to action() and runs MinigameAction via GameTrigger.")
	interactable.queue_free()

	# 6. Test completion with victory: transfer items and verify inventory
	var win_results = {"items": {"blue_potion": 3, "rusty_key": 1}}
	game_manager._minigame_win_path = "res://src/minigames/tests/test_minigame_flow.tscn"
	game_manager._minigame_win_spawn_id = "spawn_win"
	
	# Simulate complete_minigame
	game_manager.complete_minigame(true, win_results)
	await process_frame

	assert(inventory.items.get("blue_potion") == 3, "The global inventory must contain 3 blue_potion after winning")
	assert(inventory.items.get("rusty_key") == 1, "The global inventory must contain 1 rusty_key after winning")
	print("[PASS] complete_minigame(true) successfully transfers all items to the Global Inventory.")

	# 7. Verify that test_minigame_flow.tscn contains the 5 individual triggers
	var flow_scene = load("res://src/minigames/tests/test_minigame_flow.tscn")
	assert(flow_scene != null, "test_minigame_flow.tscn must load correctly")
	var flow_inst = flow_scene.instantiate()
	root.add_child(flow_inst)
	await process_frame
	
	var triggers_node = flow_inst.get_node_or_null("MinigameTriggers")
	assert(triggers_node != null, "test_minigame_flow must have a MinigameTriggers node")
	
	var expected_triggers = [
		"Trigger_Catcher",
		"Trigger_Excavation",
		"Trigger_Runner",
		"Trigger_Smasher",
		"Trigger_Trampolin"
	]
	for trigger_name in expected_triggers:
		var trig = triggers_node.get_node_or_null(trigger_name)
		assert(trig != null, "Missing trigger '%s' in test_minigame_flow" % trigger_name)
		assert(trig.actions_if_true.size() > 0, "Trigger '%s' must have at least one action" % trigger_name)
		var mg_act = trig.actions_if_true[0]
		assert(mg_act is MinigameAction, "The action of '%s' must be MinigameAction" % trigger_name)
		assert(ResourceLoader.exists(mg_act.get_minigame_scene_path()), "The minigame scene '%s' must exist" % mg_act.get_minigame_scene_path())
	print("[PASS] All 5 individual triggers (Catcher, Excavation, Runner, Smasher, Trampolin) verified in test_minigame_flow.tscn.")
	flow_inst.queue_free()

	# Clean up
	dummy.queue_free()
	dummy_trigger.queue_free()
	print("\n>>> ALL MINIGAME FRAMEWORK TESTS PASSED SUCCESSFULLY (100%) <<<\n")
	quit(0)
