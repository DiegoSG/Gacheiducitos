extends SceneTree

const LootDropComponent = preload("res://src/shared/components/loot_drop_component.gd")

func _init() -> void:
	print("\n--- TEST: SISTEMA DE LOOT Y DROPS DE ENEMIGOS + INVENTARIO TAB ---")
	
	# Inicializar Autoloads necesarios si no existen
	var nm = root.get_node_or_null("NarrativeManager")
	if not nm:
		var nm_script = load("res://src/core/narrative_manager.gd")
		nm = nm_script.new()
		nm.name = "NarrativeManager"
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
	# Test 1: Asignación directa de ítems y probabilidades
	# ----------------------------------------------------
	print("[PASS] Carga de recursos ItemData verificada.")
	
	# ----------------------------------------------------
	# Test 2: LootDropComponent - Drop de probabilidad 10 (Siempre) vs 0 (Nunca)
	# ----------------------------------------------------
	var loot_comp = LootDropComponent.new()
	root.add_child(loot_comp)
	loot_comp.loot_table.clear()
	loot_comp.loot_table[red_potion] = 10
	loot_comp.loot_table[green_herb] = 0
	loot_comp.drop_count = 5
	loot_comp.enable_coins = false
	
	var dropped_always_count: int = 0
	var dropped_never_count: int = 0
	var trials: int = 50
	
	for i in range(trials):
		var drops = loot_comp.drop_loot()
		for d in drops:
			if d.item_data.id == "red_potion":
				dropped_always_count += 1
			elif d.item_data.id == "green_herb":
				dropped_never_count += 1
			d.queue_free()
		await process_frame
		
	assert(dropped_always_count == trials, "El ítem con prob 10 debe caer el 100% de las veces (50/50)")
	assert(dropped_never_count == 0, "El ítem con prob 0 NUNCA debe caer (0/50)")
	print("[PASS] Probabilidad 10 (siempre) y 0 (nunca) comprobadas con %d tiradas." % trials)
	
	# ----------------------------------------------------
	# Test 3: Drop Count Limit
	# ----------------------------------------------------
	loot_comp.loot_table.clear()
	loot_comp.loot_table[red_potion] = 10
	loot_comp.loot_table[green_herb] = 10
	loot_comp.drop_count = 1
	
	for i in range(20):
		var drops = loot_comp.drop_loot()
		assert(drops.size() <= 1, "No debe soltar más ítems que drop_count (1)")
		for d in drops:
			d.queue_free()
		await process_frame
	print("[PASS] Límite de drop_count respetado estrictamente.")
	
	# ----------------------------------------------------
	# Test 4: Ítem Único (One-Time Drop) con persistence_id
	# ----------------------------------------------------
	loot_comp.unique_item = golden_key
	loot_comp.unique_probability = 10
	loot_comp.persistence_id = "test_boss_key_drop"
	loot_comp.loot_table.clear()
	loot_comp.enable_coins = false
	
	# Primera muerte -> Debe soltar golden_key
	var first_drops = loot_comp.drop_loot()
	assert(first_drops.size() == 1, "Debe soltar el ítem único la primera vez")
	assert(first_drops[0].item_data.id == "golden_key", "El drop debe ser la golden_key")
	assert(wsm != null and wsm.has_state("test_boss_key_drop"), "El estado debe guardarse en WorldStateManager")
	assert(wsm.load_state("test_boss_key_drop").get("unique_dropped", false) == true, "unique_dropped debe ser true en WSM")
	for d in first_drops:
		d.queue_free()
	await process_frame
	
	# Segunda muerte (mismo componente o reaparición con persistence_id guardado) -> NO debe soltar golden_key
	var second_drops = loot_comp.drop_loot()
	assert(second_drops.is_empty(), "No debe volver a soltar el ítem único una vez entregado")
	print("[PASS] Ítem Único (One-Time Drop) verificado y persistido en WorldStateManager.")
	
	# ----------------------------------------------------
	# Test 5: Monedas en Rango Aleatorio
	# ----------------------------------------------------
	loot_comp.unique_item = null
	loot_comp.enable_coins = true
	loot_comp.min_coins = 3
	loot_comp.max_coins = 7
	
	for i in range(30):
		var drops = loot_comp.drop_loot()
		assert(drops.size() == 1, "Debe haber 1 drop de monedas")
		var coin_drop = drops[0]
		assert(coin_drop.item_data.id == "gold_coins", "El drop debe ser gold_coins")
		assert(coin_drop.custom_amount >= 3 and coin_drop.custom_amount <= 7, "Monedas fuera de rango [3, 7]")
		coin_drop.queue_free()
		await process_frame
	print("[PASS] Rango de monedas aleatorio [3, 7] verificado.")
	
	# ----------------------------------------------------
	# Test 6: Recolección e Inventario + Monedas (con guardia de animación de drop)
	# ----------------------------------------------------
	var initial_gold: int = ps.gold
	var mock_player = CharacterBody2D.new()
	mock_player.name = "Player"
	mock_player.add_to_group("player")
	root.add_child(mock_player)
	
	var test_coin_drop = loot_comp._spawn_pickup(gold_coins, 15, Vector2.ZERO)
	await process_frame
	# Fase 1: Durante el drop, can_be_collected es false y no se absorbe prematuramente
	assert(test_coin_drop.can_be_collected == false, "can_be_collected debe ser false durante la caída")
	test_coin_drop._on_body_entered(mock_player)
	assert(ps.gold == initial_gold, "No debe sumar monedas antes de terminar el drop")
	
	# Fase 2: Al aterrizar, se habilita la recolección
	test_coin_drop._on_drop_animation_finished()
	assert(test_coin_drop.can_be_collected == true, "can_be_collected debe ser true tras aterrizar")
	test_coin_drop._on_body_entered(mock_player)
	assert(ps.gold == initial_gold + 15, "PlayerStats no sumó la cantidad de monedas correcta tras aterrizar")
	
	var initial_potions: int = inv.get_items().get("red_potion", 0)
	var test_potion_drop = loot_comp._spawn_pickup(red_potion, 2, Vector2.ZERO)
	await process_frame
	test_potion_drop._on_drop_animation_finished()
	test_potion_drop._on_body_entered(mock_player)
	assert(inv.get_items().get("red_potion") == initial_potions + 2, "Inventory no sumó el ítem recogido tras aterrizar")
	print("[PASS] Drop cinemático sin físicas, guardia de cooldown y recolección verificados.")
	
	# ----------------------------------------------------
	# Test 7: Diccionario tipado loot_table
	# ----------------------------------------------------
	loot_comp.loot_table.clear()
	loot_comp.loot_table[red_potion] = 8
	loot_comp.loot_table[green_herb] = 5
	loot_comp.loot_table[golden_key] = 2
	assert(loot_comp.loot_table.size() == 3, "loot_table debe contener 3 entradas")
	assert(loot_comp.loot_table[red_potion] == 8, "Probabilidad de red_potion debe ser 8")
	print("[PASS] Configuración de loot_table como Dictionary[ItemData, int] verificada.")
	
	# ----------------------------------------------------
	# Test 8: InventoryUI con tecla TAB
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
	print("[PASS] Toggle de apertura y cierre de InventoryUI (TAB) verificado.")
	
	# Limpieza
	loot_comp.queue_free()
	mock_player.queue_free()
	inv_ui.queue_free()
	
	print("\n--- TODOS LOS TESTS DE LOOT, DROPS E INVENTARIO PASARON EXITOSAMENTE ---\n")
	quit(0)
