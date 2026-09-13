extends SceneTree

const HUD_SCENE = preload("res://src/ui/loot_feedback/player_hud.tscn")
const LootToastItem = preload("res://src/ui/loot_feedback/loot_toast_item.gd")

func _init() -> void:
	print("\n--- TEST: FEEDBACK VISUAL DE INVENTARIO (LOOT TOAST STACK + MONEDAS) ---")
	
	# Autoloads mínimos requeridos
	var inv = root.get_node_or_null("Inventory")
	if not inv:
		var inv_script = load("res://src/core/inventory.gd")
		inv = inv_script.new()
		inv.name = "Inventory"
		root.add_child(inv)
		
	var item_db = root.get_node_or_null("ItemDatabase")
	if not item_db:
		var db_script = load("res://src/core/item_database.gd")
		item_db = db_script.new()
		item_db.name = "ItemDatabase"
		root.add_child(item_db)
		
	await process_frame
	
	var green_herb: ItemData = load("res://data/items/green_herb.tres")
	var red_potion: ItemData = load("res://data/items/red_potion.tres")
	var blue_gem: ItemData = load("res://data/items/blue_gem.tres")
	var gold_coins: ItemData = load("res://data/items/gold_coins.tres")
	
	assert(green_herb != null, "green_herb.tres debe existir")
	assert(red_potion != null, "red_potion.tres debe existir")
	assert(blue_gem != null, "blue_gem.tres debe existir")
	assert(gold_coins != null, "gold_coins.tres debe existir")
	
	# Instanciar PlayerHUD
	var hud = HUD_SCENE.instantiate() as LootFeedbackManager
	root.add_child(hud)
	await process_frame
	
	assert(LootFeedbackManager.instance == hud, "LootFeedbackManager.instance debe ser el HUD activo")
	assert(hud.toast_container != null, "ToastContainer debe estar presente en el HUD")
	print("[PASS] Instanciación y registro de PlayerHUD y ToastContainer verificados.")
	
	# ----------------------------------------------------
	# Test 1: Creación de un toast individual directo (sin animación voladora)
	# ----------------------------------------------------
	LootFeedbackManager.trigger_loot_pickup(green_herb, Vector2(100, 100), 1)
	await process_frame
	
	assert(hud.toast_container.get_child_count() == 1, "Debe existir 1 toast en el contenedor")
	var toast1 = hud.toast_container.get_child(0) as LootToastItem
	assert(toast1 != null, "El hijo debe ser de tipo LootToastItem")
	assert(toast1.item_id == "green_herb", "El item_id debe ser green_herb")
	assert(toast1.current_amount == 1, "La cantidad inicial debe ser 1")
	assert(toast1.count_label.text == "x 1", "El texto del label debe ser 'x 1'")
	print("[PASS] Test 1: Creación directa e instantánea de toast validada ('green_herb x 1').")
	
	# ----------------------------------------------------
	# Test 2: Apilamiento dinámico de ítems iguales ('x N')
	# ----------------------------------------------------
	LootFeedbackManager.trigger_loot_pickup(green_herb, Vector2(150, 150), 2)
	await process_frame
	
	assert(hud.toast_container.get_child_count() == 1, "No debe crearse un nuevo nodo al recibir el mismo ítem")
	assert(toast1.current_amount == 3, "La cantidad debe haberse sumado (1 + 2 = 3)")
	assert(toast1.count_label.text == "x 3", "El texto debe actualizarse a 'x 3'")
	assert(toast1.remaining_time > toast1.DISPLAY_DURATION - 0.2, "El temporizador debe reiniciarse al apilar")
	print("[PASS] Test 2: Apilado de ítems idénticos ('x N') sin duplicar nodos validado.")
	
	# ----------------------------------------------------
	# Test 3: Múltiples ítems distintos (pila vertical)
	# ----------------------------------------------------
	LootFeedbackManager.trigger_toast(red_potion, 1)
	LootFeedbackManager.trigger_toast(blue_gem, 4)
	await process_frame
	
	assert(hud.toast_container.get_child_count() == 3, "Deben existir 3 toasts activos en la pila")
	var toast2 = hud.toast_container.get_child(1) as LootToastItem
	var toast3 = hud.toast_container.get_child(2) as LootToastItem
	assert(toast2.item_id == "red_potion" and toast2.current_amount == 1, "Toast 2 correcto")
	assert(toast3.item_id == "blue_gem" and toast3.current_amount == 4, "Toast 3 correcto")
	assert(toast3.count_label.text == "x 4", "Toast 3 texto 'x 4' correcto")
	print("[PASS] Test 3: Pila vertical de múltiples tipos de ítems validada.")
	
	# ----------------------------------------------------
	# Test 4: Soporte y apilado de Monedas de Oro
	# ----------------------------------------------------
	LootFeedbackManager.trigger_gold(25)
	await process_frame
	
	assert(hud._active_toasts.has("gold_coins"), "Debe existir un toast para gold_coins")
	var toast_gold = hud._active_toasts["gold_coins"] as LootToastItem
	assert(toast_gold.current_amount == 25, "La cantidad inicial de oro debe ser 25")
	assert(toast_gold.count_label.text == "x 25", "El label debe mostrar 'x 25'")
	
	# Sumar más monedas y validar apilado acumulativo
	LootFeedbackManager.trigger_gold(15)
	await process_frame
	
	assert(toast_gold.current_amount == 40, "La cantidad de oro debe acumularse a 40 (25 + 15)")
	assert(toast_gold.count_label.text == "x 40", "El label debe actualizarse a 'x 40'")
	print("[PASS] Test 4: Soporte de monedas de oro y apilamiento acumulativo validado ('gold_coins x 40').")
	
	# ----------------------------------------------------
	# Test 5: Expiración y limpieza de memoria
	# ----------------------------------------------------
	# Forzar expiración inmediata de toast2 (red_potion)
	toast2.remaining_time = 0.0
	toast2._process(0.1) # Disparar fade out
	assert(toast2._is_fading == true, "El toast debe entrar en estado de desvanecimiento")
	
	# Completar el fade out
	toast2._fade_tween.custom_step(toast2.FADE_DURATION + 0.1)
	await process_frame
	await process_frame
	
	assert(not hud._active_toasts.has("red_potion"), "El ítem expirado debe removerse del diccionario _active_toasts")
	print("[PASS] Test 5: Expiración y limpieza de memoria en _active_toasts validada.")
	
	print("\n>>> TODOS LOS TESTS DE LOOT FEEDBACK (TOAST STACK + MONEDAS) PASARON AL 100% <<<\n")
	hud.queue_free()
	quit(0)
