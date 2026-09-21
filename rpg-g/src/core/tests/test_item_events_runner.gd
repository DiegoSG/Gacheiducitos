extends SceneTree

## Runner de pruebas unitarias y de integración para ItemAction,
## el pipeline de GameTrigger, DialogueEvent y la sincronización con Inventory.

var _tests_passed: int = 0
var _tests_failed: int = 0

var _action_finished: bool = false
var _event_executed: bool = false

func _on_action_finished() -> void:
	_action_finished = true

func _on_event_executed() -> void:
	_event_executed = true

func _init() -> void:
	print("\n=======================================================")
	print("--- TEST RUNNER: ITEM EVENTS & PIPELINE INTEGRATION ---")
	print("=======================================================\n")
	_run_all_tests()

func _record_result(test_name: String, success: bool, details: String = "") -> void:
	if success:
		_tests_passed += 1
		print("[PASS] %s" % test_name)
	else:
		_tests_failed += 1
		printerr("[FAIL] %s: %s" % [test_name, details])

func _run_all_tests() -> void:
	# 1. Asegurar Autoloads esenciales
	_ensure_autoloads()
	await process_frame

	var inventory: Node = root.get_node_or_null("Inventory")
	assert(inventory != null, "Inventory autoload debe existir")

	var dummy_trigger_node: Node2D = Node2D.new()
	dummy_trigger_node.name = "DummyTriggerNode"
	root.add_child(dummy_trigger_node)
	await process_frame

	# ----------------------------------------------------
	# Test 1: Verificar existencia de items .tres en data/items/
	# ----------------------------------------------------
	var item_db: Node = root.get_node_or_null("ItemDatabase")
	var green_herb: ItemData = item_db.get_item("green_herb") if item_db else null
	var red_potion: ItemData = item_db.get_item("red_potion") if item_db else null
	var gold_coins: ItemData = item_db.get_item("gold_coins") if item_db else null

	var items_ok: bool = (green_herb != null and red_potion != null and gold_coins != null)
	_record_result("ItemDatabase: Ítems base cargados correctamente (.tres)", items_ok, "Faltan items esenciales en data/items/")

	# ----------------------------------------------------
	# Test 2: ItemAction con operation='add' suma al inventario
	# ----------------------------------------------------
	inventory.items.clear()
	var add_action: ItemAction = ItemAction.new()
	add_action.item_id = "green_herb"
	add_action.amount = 3
	add_action.operation = "add"
	add_action.show_feedback = false

	_action_finished = false
	add_action.finished.connect(_on_action_finished, CONNECT_ONE_SHOT)
	add_action.execute(dummy_trigger_node)

	var add_ok: bool = (inventory.items.get("green_herb", 0) == 3 and _action_finished)
	_record_result("ItemAction (add): Suma ítems al inventario y emite finished", add_ok, "Esperado 3 green_herb, obtenido: %s" % str(inventory.items.get("green_herb")))

	# Acumulación adicional (3 + 2 = 5)
	_action_finished = false
	add_action.amount = 2
	add_action.finished.connect(_on_action_finished, CONNECT_ONE_SHOT)
	add_action.execute(dummy_trigger_node)

	var accum_ok: bool = (inventory.items.get("green_herb", 0) == 5 and _action_finished)
	_record_result("ItemAction (add acumulativo): Incrementa cantidad existente a 5", accum_ok, "Esperado 5 green_herb, obtenido: %s" % str(inventory.items.get("green_herb")))

	# ----------------------------------------------------
	# Test 3: ItemAction con operation='remove' resta del inventario
	# ----------------------------------------------------
	var remove_action: ItemAction = ItemAction.new()
	remove_action.item_id = "green_herb"
	remove_action.amount = 2
	remove_action.operation = "remove"

	_action_finished = false
	remove_action.finished.connect(_on_action_finished, CONNECT_ONE_SHOT)
	remove_action.execute(dummy_trigger_node)

	var remove_ok: bool = (inventory.items.get("green_herb", 0) == 3 and _action_finished)
	_record_result("ItemAction (remove parcial): Resta 2 ítems, quedan 3", remove_ok, "Esperado 3 green_herb, obtenido: %s" % str(inventory.items.get("green_herb")))

	# Remoción total (3 - 3 = 0 -> borrado de clave)
	_action_finished = false
	remove_action.amount = 3
	remove_action.finished.connect(_on_action_finished, CONNECT_ONE_SHOT)
	remove_action.execute(dummy_trigger_node)

	var total_remove_ok: bool = (not inventory.items.has("green_herb") and _action_finished)
	_record_result("ItemAction (remove total): Borra la clave al llegar a 0", total_remove_ok, "La clave green_herb aún existe")

	# Remoción sobre ítem inexistente (no debe crashear)
	_action_finished = false
	remove_action.item_id = "non_existent_item"
	remove_action.amount = 1
	remove_action.finished.connect(_on_action_finished, CONNECT_ONE_SHOT)
	remove_action.execute(dummy_trigger_node)

	var non_existent_ok: bool = _action_finished
	_record_result("ItemAction (remove inexistente): Maneja ausencia de ítem sin crashear", non_existent_ok, "No emitió finished")

	# ----------------------------------------------------
	# Test 4: Emisión de señal 'finished' en casos límite (edge cases)
	# ----------------------------------------------------
	# 4a: ID vacío
	var empty_id_action: ItemAction = ItemAction.new()
	empty_id_action.item_id = ""
	empty_id_action.amount = 5
	_action_finished = false
	empty_id_action.finished.connect(_on_action_finished, CONNECT_ONE_SHOT)
	empty_id_action.execute(dummy_trigger_node)
	_record_result("Edge Case (item_id vacío): Emite finished y no crashea", _action_finished, "No emitió finished")

	# 4b: Cantidad 0
	var zero_amount_action: ItemAction = ItemAction.new()
	zero_amount_action.item_id = "red_potion"
	zero_amount_action.amount = 0
	_action_finished = false
	zero_amount_action.finished.connect(_on_action_finished, CONNECT_ONE_SHOT)
	zero_amount_action.execute(dummy_trigger_node)
	_record_result("Edge Case (amount = 0): Emite finished y no crashea", _action_finished, "No emitió finished")

	# 4c: Cantidad negativa
	var neg_amount_action: ItemAction = ItemAction.new()
	neg_amount_action.item_id = "red_potion"
	neg_amount_action.amount = -3
	_action_finished = false
	neg_amount_action.finished.connect(_on_action_finished, CONNECT_ONE_SHOT)
	neg_amount_action.execute(dummy_trigger_node)
	_record_result("Edge Case (amount < 0): Emite finished y no crashea", _action_finished, "No emitió finished")

	# 4d: Operación desconocida
	var unknown_op_action: ItemAction = ItemAction.new()
	unknown_op_action.item_id = "red_potion"
	unknown_op_action.amount = 1
	unknown_op_action.operation = "unknown_operation"
	_action_finished = false
	unknown_op_action.finished.connect(_on_action_finished, CONNECT_ONE_SHOT)
	unknown_op_action.execute(dummy_trigger_node)
	_record_result("Edge Case (operación inválida): Emite finished y no crashea", _action_finished, "No emitió finished")

	# ----------------------------------------------------
	# Test 5: Integración con LootFeedbackManager (ausente y presente)
	# ----------------------------------------------------
	# Caso 5a: LootFeedbackManager ausente (LootFeedbackManager.instance == null)
	var feedback_action: ItemAction = ItemAction.new()
	feedback_action.item_id = "green_herb"
	feedback_action.amount = 1
	feedback_action.operation = "add"
	feedback_action.show_feedback = true

	_action_finished = false
	feedback_action.finished.connect(_on_action_finished, CONNECT_ONE_SHOT)
	feedback_action.execute(dummy_trigger_node)
	_record_result("LootFeedbackManager (HUD ausente): Ejecución silenciosa y segura", _action_finished, "Falló al ejecutar sin HUD")

	# Caso 5b: LootFeedbackManager presente (PlayerHUD activo)
	var hud_scene: PackedScene = load("res://src/ui/loot_feedback/player_hud.tscn")
	var hud: LootFeedbackManager = null
	if hud_scene:
		hud = hud_scene.instantiate() as LootFeedbackManager
		root.add_child(hud)
		await process_frame

	var hud_active_ok: bool = (hud != null and LootFeedbackManager.instance == hud)
	if hud_active_ok:
		_action_finished = false
		feedback_action.finished.connect(_on_action_finished, CONNECT_ONE_SHOT)
		feedback_action.execute(dummy_trigger_node)
		await process_frame

		var toast_ok: bool = (hud.toast_container != null and hud.toast_container.get_child_count() > 0)
		_record_result("LootFeedbackManager (HUD presente): Genera Toast visual en contenedor", toast_ok and _action_finished, "No se generó el toast en toast_container")
		hud.queue_free()
		await process_frame
	else:
		_record_result("LootFeedbackManager (HUD presente): Carga de escena de HUD", false, "No se pudo instanciar player_hud.tscn")

	# ----------------------------------------------------
	# Test 6: GameTrigger ejecutando ItemAction
	# ----------------------------------------------------
	var trigger: GameTrigger = GameTrigger.new()
	trigger.name = "TestGameTrigger"
	trigger.one_shot = false
	root.add_child(trigger)
	await process_frame

	var trigger_item_action: ItemAction = ItemAction.new()
	trigger_item_action.item_id = "red_potion"
	trigger_item_action.amount = 2
	trigger_item_action.operation = "add"
	trigger_item_action.show_feedback = false
	trigger.actions_if_true.append(trigger_item_action)

	inventory.items.erase("red_potion")
	trigger.force_trigger()
	await process_frame

	var trigger_ok: bool = (inventory.items.get("red_potion", 0) == 2)
	_record_result("GameTrigger -> ItemAction: Ejecución de acción desde GameTrigger", trigger_ok, "Esperado 2 red_potion, obtenido: %s" % str(inventory.items.get("red_potion")))
	trigger.queue_free()

	# ----------------------------------------------------
	# Test 7: DialogueEvent ejecutando ItemAction vía GameManager.trigger_event
	# ----------------------------------------------------
	var dialogue_evt: DialogueEvent = DialogueEvent.new()
	dialogue_evt.name = "TestDialogueEvent"
	dialogue_evt.event_id = "give_gold_reward"
	dialogue_evt.one_shot = true

	var dialogue_item_action: ItemAction = ItemAction.new()
	dialogue_item_action.item_id = "gold_coins"
	dialogue_item_action.amount = 50
	dialogue_item_action.operation = "add"
	dialogue_item_action.show_feedback = false
	dialogue_evt.actions.append(dialogue_item_action)

	root.add_child(dialogue_evt)
	await process_frame

	_event_executed = false
	dialogue_evt.event_executed.connect(_on_event_executed, CONNECT_ONE_SHOT)

	inventory.items.erase("gold_coins")
	var gm: Node = root.get_node_or_null("GameManager")
	assert(gm != null, "GameManager autoload requerido")
	gm.trigger_event("give_gold_reward")
	await process_frame

	var dialogue_ok: bool = (_event_executed and inventory.items.get("gold_coins", 0) == 50)
	_record_result("DialogueEvent -> ItemAction: Activación remota vía GameManager.trigger_event", dialogue_ok, "Esperado 50 gold_coins, obtenido: %s" % str(inventory.items.get("gold_coins")))

	# Comprobar one_shot en DialogueEvent (segundo disparo no debe sumar)
	_event_executed = false
	gm.trigger_event("give_gold_reward")
	await process_frame
	var one_shot_ok: bool = (not _event_executed and inventory.items.get("gold_coins", 0) == 50)
	_record_result("DialogueEvent (one_shot): No repite adición de ítems en disparos subsecuentes", one_shot_ok, "DialogueEvent se ejecutó más de una vez")

	dialogue_evt.queue_free()
	dummy_trigger_node.queue_free()

	# ----------------------------------------------------
	# Resumen final
	# ----------------------------------------------------
	print("\n=======================================================")
	print("RESULTADOS: %d PASARON | %d FALLARON" % [_tests_passed, _tests_failed])
	print("=======================================================")

	if _tests_failed == 0:
		print(">>> TODOS LOS TESTS DE EVENTOS DE ÍTEMS PASARON CON ÉXITO <<<\n")
		quit(0)
	else:
		printerr(">>> HUBO FALLOS EN LAS PRUEBAS DE EVENTOS DE ÍTEMS <<<\n")
		quit(1)

func _ensure_autoloads() -> void:
	if not root.get_node_or_null("Inventory"):
		var inv_script: Script = load("res://src/core/inventory.gd")
		var inv: Node = inv_script.new()
		inv.name = "Inventory"
		root.add_child(inv)

	if not root.get_node_or_null("ItemDatabase"):
		var db_script: Script = load("res://src/core/item_database.gd")
		var db: Node = db_script.new()
		db.name = "ItemDatabase"
		root.add_child(db)

	if not root.get_node_or_null("GameManager"):
		var gm_script: Script = load("res://src/core/game_manager.gd")
		var gm: Node = gm_script.new()
		gm.name = "GameManager"
		root.add_child(gm)

	if not root.get_node_or_null("WorldStateManager"):
		var wsm_script: Script = load("res://src/core/world_state_manager.gd")
		var wsm: Node = wsm_script.new()
		wsm.name = "WorldStateManager"
		root.add_child(wsm)
