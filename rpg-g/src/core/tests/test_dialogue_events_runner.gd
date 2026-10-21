extends SceneTree

## Headless test runner to verify dialogue events:
## Synchronization GameManager -> DialogueEvent / OnEventListener -> GameTrigger
## Checks:
## 1. GameManager.trigger_event() -> DialogueEvent (by event_id)
## 2. Match by event_id and fallback by node.name
## 3. one_shot behavior (blocking on second trigger)
## 4. event_executed signal emission
## 5. Persistence via WorldStateManager (saving and restoring _has_triggered)
## 6. OnEventListener -> GameTrigger (conditions and alternative pipeline)

var _event_executed_emitted: bool = false

func _on_event_executed() -> void:
	_event_executed_emitted = true

func _init() -> void:
	print("\n===================================================================")
	print("=== RUNNER TEST: DIALOGUE EVENT SYSTEM AND PERSISTENCE ===")
	print("===================================================================\n")

	# Wait for the engine to initialize the scene and autoloads in headless mode
	await process_frame

	# Ensure the essential Autoloads are present
	var gm: Node = root.get_node_or_null("GameManager")
	if not gm:
		var gm_script: GDScript = load("res://src/core/game_manager.gd")
		gm = gm_script.new()
		gm.name = "GameManager"
		root.add_child(gm)

	var wsm: Node = root.get_node_or_null("WorldStateManager")
	if not wsm:
		var wsm_script: GDScript = load("res://src/core/world_state_manager.gd")
		wsm = wsm_script.new()
		wsm.name = "WorldStateManager"
		root.add_child(wsm)

	var nm: Node = root.get_node_or_null("GameVariables")
	if not nm:
		var nm_script: GDScript = load("res://src/core/game_variables.gd")
		nm = nm_script.new()
		nm.name = "GameVariables"
		root.add_child(nm)

	var inv: Node = root.get_node_or_null("Inventory")
	if not inv:
		var inv_script: GDScript = load("res://src/core/inventory.gd")
		inv = inv_script.new()
		inv.name = "Inventory"
		root.add_child(inv)

	await process_frame

	# Clear previous persistent state for a clean test environment
	wsm.clear_all()

	# -------------------------------------------------------------------------
	# TEST 1: Full flow GameManager.trigger_event() -> DialogueEvent (event_id)
	# -------------------------------------------------------------------------
	print("[TEST 1] Full flow: GameManager.trigger_event() -> DialogueEvent with event_id...")
	
	var dlg_event_1: DialogueEvent = DialogueEvent.new()
	dlg_event_1.name = "DialogueEventTest1"
	dlg_event_1.event_id = "test_evt_1"
	dlg_event_1.one_shot = true
	dlg_event_1.persistence_id = "test_pers_1"

	var flag_act_1: VariableAction = VariableAction.new()
	flag_act_1.var_path = "flag.test_flag_1"
	flag_act_1.value = "true"
	dlg_event_1.actions.append(flag_act_1)

	_event_executed_emitted = false
	dlg_event_1.event_executed.connect(_on_event_executed)

	root.add_child(dlg_event_1)
	await process_frame

	assert(nm.get_var("flag.test_flag_1") != true, "The initial flag must not be true before the event")
	assert(_event_executed_emitted == false, "event_executed should not have been emitted yet")

	# Fire event from GameManager
	gm.trigger_event("test_evt_1")
	await process_frame

	assert(_event_executed_emitted == true, "The event_executed signal should have been emitted")
	assert(nm.get_var("flag.test_flag_1") == true, "The flag in GameVariables should have changed to true via VariableAction")
	assert(dlg_event_1._has_triggered == true, "_has_triggered should be true after execution")
	print("[PASS] Test 1 passed: DialogueEvent received event 'test_evt_1', ran VariableAction and emitted event_executed.")

	# -------------------------------------------------------------------------
	# TEST 2: Match by node name (fallback if event_id is empty or matches)
	# -------------------------------------------------------------------------
	print("\n[TEST 2] Match check: event_id vs node.name...")

	var dlg_event_by_name: DialogueEvent = DialogueEvent.new()
	dlg_event_by_name.name = "CustomNamedNode"
	dlg_event_by_name.event_id = "" # Intentionally empty
	dlg_event_by_name.one_shot = true
	dlg_event_by_name.persistence_id = "test_pers_by_name"

	var flag_act_by_name: VariableAction = VariableAction.new()
	flag_act_by_name.var_path = "flag.flag_node_name_matched"
	flag_act_by_name.value = "true"
	dlg_event_by_name.actions.append(flag_act_by_name)

	root.add_child(dlg_event_by_name)
	await process_frame

	# Trigger using the node name
	gm.trigger_event("CustomNamedNode")
	await process_frame

	assert(nm.get_var("flag.flag_node_name_matched") == true, "DialogueEvent must respond to the node name if it matches")
	print("[PASS] Match by node.name verified: the event responded to the node name when event_id was empty.")

	# Verify that an unrelated event does not trigger the node
	var dlg_event_isolated: DialogueEvent = DialogueEvent.new()
	dlg_event_isolated.name = "IsolatedNode"
	dlg_event_isolated.event_id = "specific_isolated_id"
	dlg_event_isolated.one_shot = true
	dlg_event_isolated.persistence_id = "test_pers_isolated"

	var flag_act_isolated: VariableAction = VariableAction.new()
	flag_act_isolated.var_path = "flag.flag_isolated_should_not_run"
	flag_act_isolated.value = "true"
	dlg_event_isolated.actions.append(flag_act_isolated)

	root.add_child(dlg_event_isolated)
	await process_frame

	gm.trigger_event("completely_unrelated_event_xyz")
	await process_frame

	assert(nm.get_var("flag.flag_isolated_should_not_run") != true, "An unknown event must not activate DialogueEvent")
	print("[PASS] Event filter verified: events that match neither event_id nor name are ignored.")

	# -------------------------------------------------------------------------
	# TEST 3: one_shot behavior (true vs false)
	# -------------------------------------------------------------------------
	print("\n[TEST 3] Validating one_shot behavior...")

	# Case A: one_shot = true
	_event_executed_emitted = false
	nm.set_var("flag.test_flag_1", false) # Reset flag to check whether it runs again
	gm.trigger_event("test_evt_1") # Second attempt on dlg_event_1
	await process_frame

	assert(_event_executed_emitted == false, "With one_shot=true, a second trigger must not emit event_executed")
	assert(nm.get_var("flag.test_flag_1") == false, "With one_shot=true, actions must not run a second time")
	print("[PASS] one_shot=true validated: second trigger was correctly blocked.")

	# Case B: one_shot = false
	var dlg_event_multi: DialogueEvent = DialogueEvent.new()
	dlg_event_multi.name = "MultiTriggerEvent"
	dlg_event_multi.event_id = "multi_evt"
	dlg_event_multi.one_shot = false
	dlg_event_multi.persistence_id = "test_pers_multi"

	var multi_fire: Dictionary = {"count": 0}
	dlg_event_multi.event_executed.connect(func() -> void: 
		multi_fire.count += 1
	)

	root.add_child(dlg_event_multi)
	await process_frame

	gm.trigger_event("multi_evt")
	await process_frame
	gm.trigger_event("multi_evt")
	await process_frame
	gm.trigger_event("multi_evt")
	await process_frame

	assert(multi_fire.count == 3, "With one_shot=false, the event should have run exactly 3 times (was: %d)" % multi_fire.count)
	print("[PASS] one_shot=false validated: allowed multiple successful activations (%d/3)." % multi_fire.count)

	# -------------------------------------------------------------------------
	# TEST 4: Persistence with WorldStateManager (Save and Restore)
	# -------------------------------------------------------------------------
	print("\n[TEST 4] Persistence with WorldStateManager...")

	const PERSIST_KEY: String = "persisted_dialogue_event_01"

	# Instance A: created, activated and saved in WorldStateManager
	var dlg_instance_a: DialogueEvent = DialogueEvent.new()
	dlg_instance_a.name = "DialogueInstanceA"
	dlg_instance_a.event_id = "persist_test_trigger"
	dlg_instance_a.one_shot = true
	dlg_instance_a.persistence_id = PERSIST_KEY

	root.add_child(dlg_instance_a)
	await process_frame

	assert(wsm.has_state(PERSIST_KEY) == false, "Before triggering, no persisted state should exist")

	gm.trigger_event("persist_test_trigger")
	await process_frame

	assert(wsm.has_state(PERSIST_KEY) == true, "WorldStateManager should have registered the persistence")
	var saved_dict: Dictionary = wsm.load_state(PERSIST_KEY)
	assert(saved_dict.get("has_triggered") == true, "The persisted state must contain has_triggered = true")
	print("[PASS] Persisted state saved correctly in WorldStateManager.")

	# Destroy instance A (simulate room change or scene reload)
	dlg_instance_a.queue_free()
	await process_frame

	# Instance B: new instance with the same persistence_id loaded in a new scene
	var dlg_instance_b: DialogueEvent = DialogueEvent.new()
	dlg_instance_b.name = "DialogueInstanceB"
	dlg_instance_b.event_id = "persist_test_trigger"
	dlg_instance_b.one_shot = true
	dlg_instance_b.persistence_id = PERSIST_KEY

	var flag_b_ran: bool = false
	dlg_instance_b.event_executed.connect(func() -> void: flag_b_ran = true)

	root.add_child(dlg_instance_b)
	# On entering the tree (_ready), calls _restore_state()
	await process_frame

	assert(dlg_instance_b._has_triggered == true, "The new instance should have restored _has_triggered=true from WorldStateManager")

	# Try triggering the event again
	gm.trigger_event("persist_test_trigger")
	await process_frame

	assert(flag_b_ran == false, "The new instance with restored state must not run actions or emit the signal")
	print("[PASS] Persistence restore validated: the new instance did not re-run the one_shot event.")

	# -------------------------------------------------------------------------
	# TEST 5: Alternative pipeline with OnEventListener and GameTrigger
	# -------------------------------------------------------------------------
	print("\n[TEST 5] OnEventListener -> GameTrigger integration with conditions...")

	var game_trigger: GameTrigger = GameTrigger.new()
	game_trigger.name = "TestGameTrigger"
	game_trigger.one_shot = true
	game_trigger.conditions = _make_quest_conditions()

	var action_true: VariableAction = VariableAction.new()
	action_true.var_path = "flag.result_branch"
	action_true.value = "TRUE_BRANCH"
	game_trigger.actions_if_true.append(action_true)

	var action_false: VariableAction = VariableAction.new()
	action_false.var_path = "flag.result_branch"
	action_false.value = "FALSE_BRANCH"
	game_trigger.actions_if_false.append(action_false)

	var listener: OnEventListener = OnEventListener.new()
	listener.name = "EventListener"
	listener.listen_for_event = "pipeline_dispatch"
	# If target_trigger is empty, OnEventListener uses get_parent()
	game_trigger.add_child(listener)

	root.add_child(game_trigger)
	await process_frame

	# Subcase A: condition not met ("quest_unlocked" is false)
	nm.set_var("flag.quest_unlocked", false)
	gm.trigger_event("pipeline_dispatch")
	await process_frame
	await process_frame

	assert(nm.get_var("flag.result_branch") == "FALSE_BRANCH", "With quest_unlocked=false, the actions_if_false branch should have run")
	print("[PASS] OnEventListener fired GameTrigger and ran actions_if_false due to the condition.")

	# Subcase B: new instance with condition met
	game_trigger.queue_free()
	await process_frame

	var game_trigger_2: GameTrigger = GameTrigger.new()
	game_trigger_2.name = "TestGameTrigger2"
	game_trigger_2.one_shot = true
	game_trigger_2.conditions = _make_quest_conditions()
	game_trigger_2.actions_if_true.append(action_true)
	game_trigger_2.actions_if_false.append(action_false)

	var listener_2: OnEventListener = OnEventListener.new()
	listener_2.listen_for_event = "pipeline_dispatch"
	game_trigger_2.add_child(listener_2)

	root.add_child(game_trigger_2)
	await process_frame

	nm.set_var("flag.quest_unlocked", true)
	gm.trigger_event("pipeline_dispatch")
	await process_frame
	await process_frame

	assert(nm.get_var("flag.result_branch") == "TRUE_BRANCH", "With quest_unlocked=true, the actions_if_true branch should have run")
	print("[PASS] OnEventListener fired GameTrigger and ran actions_if_true correctly.")

	# -------------------------------------------------------------------------
	# TEST 6: Event execution simulation with ItemAction
	# -------------------------------------------------------------------------
	print("\n[TEST 6] Validating ItemAction inside DialogueEvent...")

	var item_db: ItemDatabase = root.get_node_or_null("ItemDatabase")
	var red_pot: ItemData = load("res://data/items/red_potion.tres")
	assert(red_pot != null, "red_potion.tres not found for the inventory test")

	var dlg_item_evt: DialogueEvent = DialogueEvent.new()
	dlg_item_evt.name = "ItemDialogueEvent"
	dlg_item_evt.event_id = "grant_potion_event"
	dlg_item_evt.one_shot = true
	dlg_item_evt.persistence_id = "item_evt_pers"

	var item_act: ItemAction = ItemAction.new()
	item_act.item = red_pot
	item_act.amount = 3
	item_act.operation = "add"
	item_act.show_feedback = false # Disable toast in headless test
	dlg_item_evt.actions.append(item_act)

	root.add_child(dlg_item_evt)
	await process_frame

	var initial_potions: int = inv.get_items().get("red_potion", 0)
	gm.trigger_event("grant_potion_event")
	await process_frame

	var final_potions: int = inv.get_items().get("red_potion", 0)
	assert(final_potions == initial_potions + 3, "ItemAction inside DialogueEvent should have added 3 potions (expected: %d, actual: %d)" % [initial_potions + 3, final_potions])
	print("[PASS] ItemAction executed correctly by DialogueEvent (3 potions added to the inventory).")

	# -------------------------------------------------------------------------
	# Clean up created nodes
	# -------------------------------------------------------------------------
	dlg_event_1.queue_free()
	dlg_event_by_name.queue_free()
	dlg_event_isolated.queue_free()
	dlg_event_multi.queue_free()
	dlg_instance_b.queue_free()
	game_trigger_2.queue_free()
	dlg_item_evt.queue_free()

	print("\n===================================================================")
	print(">>> ALL DIALOGUE EVENT TESTS PASSED SUCCESSFULLY 100% <<<")
	print("===================================================================\n")

	quit(0)

## ConditionSet: flag.quest_unlocked == true
func _make_quest_conditions() -> ConditionSet:
	var cond: Condition = Condition.new()
	cond.var_path = "flag.quest_unlocked"
	cond.value = "true"
	var set_res: ConditionSet = ConditionSet.new()
	set_res.conditions.append(cond)
	return set_res
