extends SceneTree


func _init() -> void:
	print("\n--- TEST: ENEMY LOOT AND DROPS SYSTEM + INVENTORY TAB ---")
	
	# Initialize the required Autoloads if they don't exist
	var nm = root.get_node_or_null("GameVariables")
	if not nm:
		var nm_script = load("res://src/core/game_variables.gd")
		nm = nm_script.new()
		nm.name = "GameVariables"
		root.add_child(nm)
		
	var inv = root.get_node_or_null("Inventory")
	if not inv:
		var inv_script = load("res://src/core/inventory.gd")
		inv = inv_script.new()
		inv.name = "Inventory"
		root.add_child(inv)
		
	var ps = root.get_node_or_null("PlayerStats")
	if not ps:
		var ps_script = load("res://src/core/player_stats.gd")
		ps = ps_script.new()
		ps.name = "PlayerStats"
		root.add_child(ps)
		
	var item_db = root.get_node_or_null("ItemDatabase")
	if not item_db:
		var db_script = load("res://src/core/item_database.gd")
		item_db = db_script.new()
		item_db.name = "ItemDatabase"
		root.add_child(item_db)

	var wsm = root.get_node_or_null("WorldStateManager")
	if not wsm:
		var wsm_script = load("res://src/core/world_state_manager.gd")
		wsm = wsm_script.new()
		wsm.name = "WorldStateManager"
		root.add_child(wsm)
		
	await process_frame
	
	var red_potion: ItemData = load("res://data/items/red_potion.tres")
	var green_herb: ItemData = load("res://data/items/green_herb.tres")
	var golden_key: ItemData = load("res://data/items/golden_key.tres")
	var gold_coins: ItemData = load("res://data/items/gold_coins.tres")
	
	assert(red_potion != null, "red_potion.tres no encontrado")
	assert(green_herb != null, "green_herb.tres no encontrado")
	assert(golden_key != null, "golden_key.tres no encontrado")
	assert(gold_coins != null, "gold_coins.tres no encontrado")
	
	# ----------------------------------------------------
	# Test 1: Direct item assignment and probabilities
	# ----------------------------------------------------
	print("[PASS] ItemData resource loading verified.")
	
	# ----------------------------------------------------
	# Test 2: DropLootAction - chance 100 (always) vs 0 (never)
	# ----------------------------------------------------
	var owner_node := Node2D.new()
	owner_node.name = "LootOwner"
	root.add_child(owner_node)

	var action := DropLootAction.new()
	action.entries = [_entry(red_potion, 100), _entry(green_herb, 0)]
	action.drop_count = 5

	var dropped_always_count: int = 0
	var dropped_never_count: int = 0
	var trials: int = 50

	for i in range(trials):
		var drops: Array[PickupItem] = action.drop(owner_node)
		for d in drops:
			if d.item_data.id == "red_potion":
				dropped_always_count += 1
			elif d.item_data.id == "green_herb":
				dropped_never_count += 1
			d.queue_free()
		await process_frame

	assert(dropped_always_count == trials, "Item with chance 100 must always drop (50/50)")
	assert(dropped_never_count == 0, "Item with chance 0 must NEVER drop (0/50)")
	print("[PASS] Chance 100 (always) and 0 (never) checked over %d rolls." % trials)

	# ----------------------------------------------------
	# Test 3: drop_count
	# ----------------------------------------------------
	action.entries = [_entry(red_potion, 100), _entry(green_herb, 100)]
	action.drop_count = 1

	for i in range(20):
		var drops: Array[PickupItem] = action.drop(owner_node)
		assert(drops.size() == 1, "With two guaranteed items and drop_count 1 it must drop exactly 1")
		for d in drops:
			d.queue_free()
		await process_frame
	print("[PASS] drop_count limit strictly respected.")

	# ----------------------------------------------------
	# Test 4: one_shot with persistence_id (special item)
	# ----------------------------------------------------
	var unique_action := DropLootAction.new()
	unique_action.entries = [_entry(golden_key, 100)]
	unique_action.one_shot = true
	unique_action.persistence_id = "test_boss_key_drop"

	var spawned_before: int = owner_node.get_parent().get_child_count()
	unique_action.execute(owner_node)
	await process_frame
	assert(wsm.has_state("test_boss_key_drop"), "State must be saved in WorldStateManager")
	assert(wsm.load_state("test_boss_key_drop").get("dropped", false) == true, "dropped must be true in WSM")
	assert(owner_node.get_parent().get_child_count() == spawned_before + 1, "Must drop the key the first time")

	unique_action.execute(owner_node)
	await process_frame
	assert(owner_node.get_parent().get_child_count() == spawned_before + 1, "Must not drop the one-shot item again")

	wsm.save_state("test_legacy_drop", {"unique_dropped": true})
	unique_action.persistence_id = "test_legacy_drop"
	unique_action.execute(owner_node)
	await process_frame
	assert(owner_node.get_parent().get_child_count() == spawned_before + 1, "Must respect the old LootDropComponent save flag")
	print("[PASS] one_shot verified, persisted in WorldStateManager and compatible with old saves.")

	# ----------------------------------------------------
	# Test 5: Amounts within range (gold)
	# ----------------------------------------------------
	var coins_entry: LootEntry = _entry(gold_coins, 100)
	coins_entry.min_amount = 3
	coins_entry.max_amount = 7
	action.entries = [coins_entry]
	action.drop_count = 1

	for i in range(30):
		var drops: Array[PickupItem] = action.drop(owner_node)
		assert(drops.size() == 1, "There must be 1 coin drop")
		var coin_drop: PickupItem = drops[0]
		assert(coin_drop.item_data.id == "gold_coins", "The drop must be gold_coins")
		assert(coin_drop.custom_amount >= 3 and coin_drop.custom_amount <= 7, "Coins out of range [3, 7]")
		coin_drop.queue_free()
		await process_frame
	print("[PASS] Random coin range [3, 7] verified.")

	# ----------------------------------------------------
	# Test 6: Pickup and Inventory + Coins (with drop animation guard)
	# ----------------------------------------------------
	var initial_gold: int = ps.gold
	var mock_player = CharacterBody2D.new()
	mock_player.name = "Player"
	mock_player.add_to_group("player")
	root.add_child(mock_player)

	var test_coin_drop: PickupItem = action._spawn_pickup(gold_coins, 15, Vector2.ZERO, root, 0)
	await process_frame
	# Phase 1: During the drop, can_be_collected is false and it is not picked up early
	assert(test_coin_drop.can_be_collected == false, "can_be_collected must be false while falling")
	test_coin_drop._on_body_entered(mock_player)
	assert(ps.gold == initial_gold, "Must not add coins before the drop finishes")

	# Phase 2: On landing, pickup is enabled
	test_coin_drop._on_drop_animation_finished()
	assert(test_coin_drop.can_be_collected == true, "can_be_collected must be true after landing")
	test_coin_drop._on_body_entered(mock_player)
	assert(ps.gold == initial_gold + 15, "PlayerStats did not add the right coin amount after landing")

	var initial_potions: int = inv.get_items().get("red_potion", 0)
	var test_potion_drop: PickupItem = action._spawn_pickup(red_potion, 2, Vector2.ZERO, root, 0)
	await process_frame
	test_potion_drop._on_drop_animation_finished()
	test_potion_drop._on_body_entered(mock_player)
	assert(inv.get_items().get("red_potion") == initial_potions + 2, "Inventory did not add the picked-up item after landing")
	print("[PASS] Physics-free kinematic drop, cooldown guard and pickup verified.")

	# ----------------------------------------------------
	# Test 8: InventoryUI with the TAB key
	# ----------------------------------------------------
	var inv_ui_scene = load("res://src/ui/inventory/inventory_ui.tscn")
	assert(inv_ui_scene != null, "inventory_ui.tscn no pudo ser cargado")
	var inv_ui = inv_ui_scene.instantiate()
	root.add_child(inv_ui)
	await process_frame
	
	assert(inv_ui.is_open() == false, "InventoryUI debe iniciar cerrado/oculto")
	inv_ui.toggle_inventory()
	assert(inv_ui.is_open() == true, "toggle_inventory() debe abrir la interfaz")
	inv_ui.toggle_inventory()
	assert(inv_ui.is_open() == false, "toggle_inventory() debe cerrar la interfaz")
	print("[PASS] InventoryUI open/close toggle (TAB) verified.")
	
	# Cleanup
	owner_node.queue_free()
	mock_player.queue_free()
	inv_ui.queue_free()
	
	print("\n--- ALL LOOT, DROPS AND INVENTORY TESTS PASSED SUCCESSFULLY ---\n")
	quit(0)

func _entry(item: ItemData, chance: int) -> LootEntry:
	var entry := LootEntry.new()
	entry.item = item
	entry.chance = chance
	return entry
