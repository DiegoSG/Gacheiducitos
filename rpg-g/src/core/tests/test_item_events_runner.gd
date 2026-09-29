extends SceneTree

## Runner de pruebas unitarias y de integración para ItemAction, GoldAction y HealthAction.

const ItemAction = preload("res://src/core/pipeline/actions/item_action.gd")
const GoldAction = preload("res://src/core/pipeline/actions/gold_action.gd")
const HealthAction = preload("res://src/core/pipeline/actions/health_action.gd")

var _passed_count: int = 0
var _failed_count: int = 0
var _action_finished: bool = false
var _event_executed: bool = false
var _last_game_event: String = ""

func _init() -> void:
	print("\n=======================================================")
	print("--- TEST RUNNER: ITEM, GOLD & HEALTH ACTIONS PIPELINE ---")
	print("=======================================================\n")

	# 1. Configurar Autoloads necesarios en headless
	var inv_script = load("res://src/core/inventory.gd")
	var inventory: Node = inv_script.new()
	inventory.name = "Inventory"
	root.add_child(inventory)

	var item_db_script = load("res://src/core/item_database.gd")
	var item_db: Node = item_db_script.new()
	item_db.name = "ItemDatabase"
	root.add_child(item_db)

	var stats_script = load("res://src/core/player_stats.gd")
	var player_stats: Node = stats_script.new()
	player_stats.name = "PlayerStats"
	root.add_child(player_stats)

	var gm_script = load("res://src/core/game_manager.gd")
	var gm: Node = gm_script.new()
	gm.name = "GameManager"
	root.add_child(gm)
	gm.game_event.connect(_on_game_event)

	await process_frame

	var dummy_trigger_node: Node2D = Node2D.new()
	dummy_trigger_node.name = "DummyTriggerNode"
	root.add_child(dummy_trigger_node)

	var green_herb: ItemData = item_db.get_item("green_herb") if item_db else null
	var red_potion: ItemData = item_db.get_item("red_potion") if item_db else null
	var gold_coins: ItemData = item_db.get_item("gold_coins") if item_db else null

	var items_ok: bool = (green_herb != null and red_potion != null and gold_coins != null)
	_record_result("ItemDatabase: Ítems base cargados correctamente (.tres)", items_ok, "Faltan items en data/items/")

	# ====================================================
	# SECCIÓN ITEM ACTION
	# ====================================================

	# Test 2: ItemAction con operation='add'
	inventory.items.clear()
	var add_action: ItemAction = ItemAction.new()
	add_action.item = green_herb
	add_action.amount = 3
	add_action.operation = "add"
	add_action.show_feedback = false
	add_action.on_success_event = "herb_added_event"

	_action_finished = false
	_last_game_event = ""
	add_action.finished.connect(_on_action_finished, CONNECT_ONE_SHOT)
	add_action.execute(dummy_trigger_node)

	var add_ok: bool = (inventory.items.get("green_herb", 0) == 3 and _action_finished and _last_game_event == "herb_added_event")
	_record_result("ItemAction (add + success event): Suma ítems y gatilla on_success_event", add_ok, "Fallo al sumar")

	# Test 3: ItemAction sustracción estricta (éxito)
	var remove_action: ItemAction = ItemAction.new()
	remove_action.item = green_herb
	remove_action.amount = 2
	remove_action.operation = "remove"
	remove_action.on_success_event = "herb_removed_ok"

	_action_finished = false
	_last_game_event = ""
	remove_action.finished.connect(_on_action_finished, CONNECT_ONE_SHOT)
	remove_action.execute(dummy_trigger_node)

	var remove_ok: bool = (inventory.items.get("green_herb", 0) == 1 and _action_finished and _last_game_event == "herb_removed_ok")
	_record_result("ItemAction (remove éxito atómico): Resta cantidad y dispara on_success_event", remove_ok, "Fallo al restar")

	# Test 4: ItemAction sustracción estricta (fallo por cantidad insuficiente)
	# Actualmente tiene 1 hierba, le pedimos 5 -> no debe descontar nada y disparar on_fail_event
	remove_action.amount = 5
	remove_action.on_fail_event = "herb_failed_not_enough"
	_action_finished = false
	_last_game_event = ""
	remove_action.finished.connect(_on_action_finished, CONNECT_ONE_SHOT)
	remove_action.execute(dummy_trigger_node)

	var fail_atomic_ok: bool = (inventory.items.get("green_herb", 0) == 1 and _action_finished and _last_game_event == "herb_failed_not_enough")
	_record_result("ItemAction (remove fallo atómico): No descuenta si falta cantidad y dispara on_fail_event", fail_atomic_ok, "Descontó indebidamente o no disparó fail")

	# Test 5: ItemAction borde (ítem null)
	var null_item_action: ItemAction = ItemAction.new()
	null_item_action.item = null
	null_item_action.on_fail_event = "null_item_fail"
	_action_finished = false
	_last_game_event = ""
	null_item_action.finished.connect(_on_action_finished, CONNECT_ONE_SHOT)
	null_item_action.execute(dummy_trigger_node)

	var null_ok: bool = (_action_finished and _last_game_event == "null_item_fail")
	_record_result("ItemAction (item null): Dispara on_fail_event y emite finished", null_ok, "No manejó item null")

	# ====================================================
	# SECCIÓN GOLD ACTION
	# ====================================================
	player_stats.gold = 50

	# Test 6: GoldAction (add)
	var gold_add: GoldAction = GoldAction.new()
	gold_add.amount = 30
	gold_add.operation = "add"
	gold_add.show_feedback = false
	gold_add.on_success_event = "gold_added_success"

	_action_finished = false
	_last_game_event = ""
	gold_add.finished.connect(_on_action_finished, CONNECT_ONE_SHOT)
	gold_add.execute(dummy_trigger_node)

	var gold_add_ok: bool = (player_stats.gold == 80 and _action_finished and _last_game_event == "gold_added_success")
	_record_result("GoldAction (add): Suma oro (50 + 30 = 80) y dispara on_success_event", gold_add_ok, "Fallo al sumar oro")

	# Test 7: GoldAction (remove éxito)
	var gold_remove: GoldAction = GoldAction.new()
	gold_remove.amount = 40
	gold_remove.operation = "remove"
	gold_remove.on_success_event = "gold_paid_success"

	_action_finished = false
	_last_game_event = ""
	gold_remove.finished.connect(_on_action_finished, CONNECT_ONE_SHOT)
	gold_remove.execute(dummy_trigger_node)

	var gold_remove_ok: bool = (player_stats.gold == 40 and _action_finished and _last_game_event == "gold_paid_success")
	_record_result("GoldAction (remove éxito): Resta oro (80 - 40 = 40) y dispara on_success_event", gold_remove_ok, "Fallo al restar oro")

	# Test 8: GoldAction (remove fallo por oro insuficiente)
	gold_remove.amount = 100 # tiene 40
	gold_remove.on_fail_event = "gold_broke_fail"

	_action_finished = false
	_last_game_event = ""
	gold_remove.finished.connect(_on_action_finished, CONNECT_ONE_SHOT)
	gold_remove.execute(dummy_trigger_node)

	var gold_fail_ok: bool = (player_stats.gold == 40 and _action_finished and _last_game_event == "gold_broke_fail")
	_record_result("GoldAction (remove fallo atómico): No descuenta si no alcanza y dispara on_fail_event", gold_fail_ok, "Descontó oro indebidamente")

	# ====================================================
	# SECCIÓN HEALTH ACTION
	# ====================================================
	player_stats.max_health = 100
	player_stats.health = 50

	# Test 9: HealthAction daño (-20 HP)
	var health_damage: HealthAction = HealthAction.new()
	health_damage.amount = -20

	_action_finished = false
	health_damage.finished.connect(_on_action_finished, CONNECT_ONE_SHOT)
	health_damage.execute(dummy_trigger_node)

	var damage_ok: bool = (player_stats.health == 30 and _action_finished)
	_record_result("HealthAction (daño con valor negativo): 50 - 20 = 30 HP", damage_ok, "Fallo al dañar")

	# Test 10: HealthAction curación (+40 HP)
	var health_heal: HealthAction = HealthAction.new()
	health_heal.amount = 40

	_action_finished = false
	health_heal.finished.connect(_on_action_finished, CONNECT_ONE_SHOT)
	health_heal.execute(dummy_trigger_node)

	var heal_ok: bool = (player_stats.health == 70 and _action_finished)
	_record_result("HealthAction (curación con valor positivo): 30 + 40 = 70 HP", heal_ok, "Fallo al curar")

	# Test 11: HealthAction full_heal (restaura al 100%)
	var health_full: HealthAction = HealthAction.new()
	health_full.full_heal = true

	_action_finished = false
	health_full.finished.connect(_on_action_finished, CONNECT_ONE_SHOT)
	health_full.execute(dummy_trigger_node)

	var full_heal_ok: bool = (player_stats.health == 100 and _action_finished)
	_record_result("HealthAction (full_heal = true): Restaura salud al 100% (100 HP)", full_heal_ok, "No restauró al 100%")

	# ====================================================
	# INTEGRACIÓN CON GAMETRIGGER Y DIALOGUEEVENT
	# ====================================================
	var trigger: GameTrigger = GameTrigger.new()
	trigger.name = "TestTrigger"
	root.add_child(trigger)
	await process_frame

	var trigger_item: ItemAction = ItemAction.new()
	trigger_item.item = red_potion
	trigger_item.amount = 2
	trigger_item.operation = "add"
	trigger_item.show_feedback = false
	trigger.actions_if_true.append(trigger_item)

	inventory.items.erase("red_potion")
	trigger.force_trigger()
	await process_frame

	var trigger_ok: bool = (inventory.items.get("red_potion", 0) == 2)
	_record_result("GameTrigger -> ItemAction: Ejecuta adición con recurso ItemData", trigger_ok, "Fallo en GameTrigger")
	trigger.queue_free()

	# ----------------------------------------------------
	# Resumen final
	# ----------------------------------------------------
	print("\n=======================================================")
	print("RESULTADOS: %d PASARON | %d FALLARON" % [_passed_count, _failed_count])
	print("=======================================================")

	if _failed_count == 0:
		print(">>> TODOS LOS TESTS DE ACCIONES PASARON CON ÉXITO <<<\n")
		quit(0)
	else:
		push_error("AL MENOS UN TEST FALLÓ")
		quit(1)

func _on_action_finished() -> void:
	_action_finished = true

func _on_game_event(event_name: String, _data: Variant) -> void:
	_last_game_event = event_name

func _record_result(test_name: String, passed: bool, error_msg: String = "") -> void:
	if passed:
		_passed_count += 1
		print("[PASS] %s" % test_name)
	else:
		_failed_count += 1
		print("[FAIL] %s - ERROR: %s" % [test_name, error_msg])
