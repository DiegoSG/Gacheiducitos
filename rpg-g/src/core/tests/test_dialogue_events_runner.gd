extends SceneTree

## Test Runner Headless para verificar eventos de diálogos:
## Sincronización GameManager -> DialogueEvent / OnEventListener -> GameTrigger
## Validaciones:
## 1. GameManager.trigger_event() -> DialogueEvent (por event_id)
## 2. Match por event_id y fallback por node.name
## 3. Comportamiento de one_shot (bloqueo en second trigger)
## 4. Emisión de señal event_executed
## 5. Persistencia mediante WorldStateManager (guardado y restauración de _has_triggered)
## 6. OnEventListener -> GameTrigger (condiciones y pipeline alternativo)

var _event_executed_emitted: bool = false

func _on_event_executed() -> void:
	_event_executed_emitted = true

func _init() -> void:
	print("\n===================================================================")
	print("=== RUNNER TEST: SISTEMA DE EVENTOS DE DIÁLOGO Y PERSISTENCIA ===")
	print("===================================================================\n")

	# Esperar a que el motor inicialice la escena y autoloads en headless
	await process_frame

	# Garantizar la presencia de Autoloads esenciales
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

	var nm: Node = root.get_node_or_null("NarrativeManager")
	if not nm:
		var nm_script: GDScript = load("res://src/core/narrative_manager.gd")
		nm = nm_script.new()
		nm.name = "NarrativeManager"
		root.add_child(nm)

	var inv: Node = root.get_node_or_null("Inventory")
	if not inv:
		var inv_script: GDScript = load("res://src/core/inventory.gd")
		inv = inv_script.new()
		inv.name = "Inventory"
		root.add_child(inv)

	await process_frame

	# Limpiar estado persistente previo para un entorno de pruebas puro
	wsm.clear_all()

	# -------------------------------------------------------------------------
	# TEST 1: Flujo completo GameManager.trigger_event() -> DialogueEvent (event_id)
	# -------------------------------------------------------------------------
	print("[TEST 1] Flujo completo: GameManager.trigger_event() -> DialogueEvent con event_id...")
	
	var dlg_event_1: DialogueEvent = DialogueEvent.new()
	dlg_event_1.name = "DialogueEventTest1"
	dlg_event_1.event_id = "test_evt_1"
	dlg_event_1.one_shot = true
	dlg_event_1.persistence_id = "test_pers_1"

	var flag_act_1: FlagAction = FlagAction.new()
	flag_act_1.flag_id = "test_flag_1"
	flag_act_1.value = "true"
	dlg_event_1.actions.append(flag_act_1)

	_event_executed_emitted = false
	dlg_event_1.event_executed.connect(_on_event_executed)

	root.add_child(dlg_event_1)
	await process_frame

	assert(nm.get_flag("test_flag_1") != true, "El flag inicial no debe ser true antes del evento")
	assert(_event_executed_emitted == false, "event_executed no debió haberse emitido todavía")

	# Disparar evento desde GameManager
	gm.trigger_event("test_evt_1")
	await process_frame

	assert(_event_executed_emitted == true, "La señal event_executed debió emitirse")
	assert(nm.get_flag("test_flag_1") == true, "El flag en NarrativeManager debió cambiar a true por FlagAction")
	assert(dlg_event_1._has_triggered == true, "_has_triggered debió ser true tras la ejecución")
	print("[PASS] Test 1 superado: DialogueEvent recibió el evento 'test_evt_1', ejecutó FlagAction y emitió event_executed.")

	# -------------------------------------------------------------------------
	# TEST 2: Match por nombre de nodo (Fallback si event_id está vacío o coincide)
	# -------------------------------------------------------------------------
	print("\n[TEST 2] Verificación de match: event_id vs node.name...")

	var dlg_event_by_name: DialogueEvent = DialogueEvent.new()
	dlg_event_by_name.name = "CustomNamedNode"
	dlg_event_by_name.event_id = "" # Vacío intencionalmente
	dlg_event_by_name.one_shot = true
	dlg_event_by_name.persistence_id = "test_pers_by_name"

	var flag_act_by_name: FlagAction = FlagAction.new()
	flag_act_by_name.flag_id = "flag_node_name_matched"
	flag_act_by_name.value = "true"
	dlg_event_by_name.actions.append(flag_act_by_name)

	root.add_child(dlg_event_by_name)
	await process_frame

	# Trigger usando el nombre del nodo
	gm.trigger_event("CustomNamedNode")
	await process_frame

	assert(nm.get_flag("flag_node_name_matched") == true, "DialogueEvent debe responder al name del nodo si coincide")
	print("[PASS] Match por node.name verificado: El evento respondió al nombre del nodo cuando event_id estaba vacío.")

	# Verificar que un evento ajeno no dispare el nodo
	var dlg_event_isolated: DialogueEvent = DialogueEvent.new()
	dlg_event_isolated.name = "IsolatedNode"
	dlg_event_isolated.event_id = "specific_isolated_id"
	dlg_event_isolated.one_shot = true
	dlg_event_isolated.persistence_id = "test_pers_isolated"

	var flag_act_isolated: FlagAction = FlagAction.new()
	flag_act_isolated.flag_id = "flag_isolated_should_not_run"
	flag_act_isolated.value = "true"
	dlg_event_isolated.actions.append(flag_act_isolated)

	root.add_child(dlg_event_isolated)
	await process_frame

	gm.trigger_event("completely_unrelated_event_xyz")
	await process_frame

	assert(nm.get_flag("flag_isolated_should_not_run") != true, "Un evento desconocido no debe activar DialogueEvent")
	print("[PASS] Filtro de eventos verificado: Eventos que no coinciden con event_id ni name son ignorados.")

	# -------------------------------------------------------------------------
	# TEST 3: Comportamiento de one_shot (true vs false)
	# -------------------------------------------------------------------------
	print("\n[TEST 3] Validación del comportamiento de one_shot...")

	# Caso A: one_shot = true
	_event_executed_emitted = false
	nm.set_flag("test_flag_1", false) # Resetear flag para comprobar si vuelve a ejecutarse
	gm.trigger_event("test_evt_1") # Segundo intento sobre dlg_event_1
	await process_frame

	assert(_event_executed_emitted == false, "Con one_shot=true, un segundo trigger no debe emitir event_executed")
	assert(nm.get_flag("test_flag_1") == false, "Con one_shot=true, las acciones no deben ejecutarse una segunda vez")
	print("[PASS] one_shot=true validado: Segundo trigger fue bloqueado correctamente.")

	# Caso B: one_shot = false
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

	assert(multi_fire.count == 3, "Con one_shot=false, el evento debió ejecutarse exactamente 3 veces (fue: %d)" % multi_fire.count)
	print("[PASS] one_shot=false validado: Permitió múltiples activaciones exitosas (%d/3)." % multi_fire.count)

	# -------------------------------------------------------------------------
	# TEST 4: Persistencia con WorldStateManager (Save y Restore)
	# -------------------------------------------------------------------------
	print("\n[TEST 4] Persistencia con WorldStateManager...")

	const PERSIST_KEY: String = "persisted_dialogue_event_01"

	# Instancia A: Se crea, se activa y se guarda en WorldStateManager
	var dlg_instance_a: DialogueEvent = DialogueEvent.new()
	dlg_instance_a.name = "DialogueInstanceA"
	dlg_instance_a.event_id = "persist_test_trigger"
	dlg_instance_a.one_shot = true
	dlg_instance_a.persistence_id = PERSIST_KEY

	root.add_child(dlg_instance_a)
	await process_frame

	assert(wsm.has_state(PERSIST_KEY) == false, "Antes de disparar, no debe existir estado persistido")

	gm.trigger_event("persist_test_trigger")
	await process_frame

	assert(wsm.has_state(PERSIST_KEY) == true, "WorldStateManager debe haber registrado la persistencia")
	var saved_dict: Dictionary = wsm.load_state(PERSIST_KEY)
	assert(saved_dict.get("has_triggered") == true, "El estado persistido debe contener has_triggered = true")
	print("[PASS] Estado persistido guardado correctamente en WorldStateManager.")

	# Destruir instancia A (simular cambio de sala o recarga de escena)
	dlg_instance_a.queue_free()
	await process_frame

	# Instancia B: Nueva instancia con la misma persistence_id cargada en una nueva escena
	var dlg_instance_b: DialogueEvent = DialogueEvent.new()
	dlg_instance_b.name = "DialogueInstanceB"
	dlg_instance_b.event_id = "persist_test_trigger"
	dlg_instance_b.one_shot = true
	dlg_instance_b.persistence_id = PERSIST_KEY

	var flag_b_ran: bool = false
	dlg_instance_b.event_executed.connect(func() -> void: flag_b_ran = true)

	root.add_child(dlg_instance_b)
	# Al entrar al árbol (_ready), llama a _restore_state()
	await process_frame

	assert(dlg_instance_b._has_triggered == true, "La nueva instancia debió restaurar _has_triggered=true desde WorldStateManager")

	# Intentar disparar el evento nuevamente
	gm.trigger_event("persist_test_trigger")
	await process_frame

	assert(flag_b_ran == false, "La nueva instancia con estado restaurado no debió ejecutar acciones ni emitir señal")
	print("[PASS] Restauración de persistencia validada: La nueva instancia no re-ejecutó el evento one_shot.")

	# -------------------------------------------------------------------------
	# TEST 5: Pipeline alternativo con OnEventListener y GameTrigger
	# -------------------------------------------------------------------------
	print("\n[TEST 5] Integración de OnEventListener -> GameTrigger con condiciones...")

	var game_trigger: GameTrigger = GameTrigger.new()
	game_trigger.name = "TestGameTrigger"
	game_trigger.one_shot = true
	game_trigger.require_condition = true
	game_trigger.condition_flag = "quest_unlocked"
	game_trigger.condition_expected_value = "true"

	var action_true: FlagAction = FlagAction.new()
	action_true.flag_id = "result_branch"
	action_true.value = "TRUE_BRANCH"
	game_trigger.actions_if_true.append(action_true)

	var action_false: FlagAction = FlagAction.new()
	action_false.flag_id = "result_branch"
	action_false.value = "FALSE_BRANCH"
	game_trigger.actions_if_false.append(action_false)

	var listener: OnEventListener = OnEventListener.new()
	listener.name = "EventListener"
	listener.listen_for_event = "pipeline_dispatch"
	# Si target_trigger está vacío, OnEventListener utiliza get_parent()
	game_trigger.add_child(listener)

	root.add_child(game_trigger)
	await process_frame

	# Subcaso A: Condición no cumplida ("quest_unlocked" es false)
	nm.set_flag("quest_unlocked", false)
	gm.trigger_event("pipeline_dispatch")
	await process_frame
	await process_frame

	assert(nm.get_flag("result_branch") == "FALSE_BRANCH", "Con quest_unlocked=false debió ejecutar la rama actions_if_false")
	print("[PASS] OnEventListener disparó GameTrigger y ejecutó actions_if_false debido a la condición.")

	# Subcaso B: Nueva instancia con condición cumplida
	game_trigger.queue_free()
	await process_frame

	var game_trigger_2: GameTrigger = GameTrigger.new()
	game_trigger_2.name = "TestGameTrigger2"
	game_trigger_2.one_shot = true
	game_trigger_2.require_condition = true
	game_trigger_2.condition_flag = "quest_unlocked"
	game_trigger_2.condition_expected_value = "true"
	game_trigger_2.actions_if_true.append(action_true)
	game_trigger_2.actions_if_false.append(action_false)

	var listener_2: OnEventListener = OnEventListener.new()
	listener_2.listen_for_event = "pipeline_dispatch"
	game_trigger_2.add_child(listener_2)

	root.add_child(game_trigger_2)
	await process_frame

	nm.set_flag("quest_unlocked", true)
	gm.trigger_event("pipeline_dispatch")
	await process_frame
	await process_frame

	assert(nm.get_flag("result_branch") == "TRUE_BRANCH", "Con quest_unlocked=true debió ejecutar la rama actions_if_true")
	print("[PASS] OnEventListener disparó GameTrigger y ejecutó actions_if_true correctamente.")

	# -------------------------------------------------------------------------
	# TEST 6: Simulación de ejecución de eventos con ItemAction
	# -------------------------------------------------------------------------
	print("\n[TEST 6] Validación de ItemAction dentro de DialogueEvent...")

	var item_db: ItemDatabase = root.get_node_or_null("ItemDatabase")
	var red_pot: ItemData = load("res://data/items/red_potion.tres")
	assert(red_pot != null, "red_potion.tres no encontrado para el test de inventario")

	var dlg_item_evt: DialogueEvent = DialogueEvent.new()
	dlg_item_evt.name = "ItemDialogueEvent"
	dlg_item_evt.event_id = "grant_potion_event"
	dlg_item_evt.one_shot = true
	dlg_item_evt.persistence_id = "item_evt_pers"

	var item_act: ItemAction = ItemAction.new()
	item_act.item_id = "red_potion"
	item_act.amount = 3
	item_act.operation = "add"
	item_act.show_feedback = false # Desactivar toast en test headless
	dlg_item_evt.actions.append(item_act)

	root.add_child(dlg_item_evt)
	await process_frame

	var initial_potions: int = inv.get_items().get("red_potion", 0)
	gm.trigger_event("grant_potion_event")
	await process_frame

	var final_potions: int = inv.get_items().get("red_potion", 0)
	assert(final_potions == initial_potions + 3, "ItemAction dentro de DialogueEvent debió añadir 3 pociones (esperado: %d, actual: %d)" % [initial_potions + 3, final_potions])
	print("[PASS] ItemAction ejecutado correctamente por DialogueEvent (3 pociones añadidas al inventario).")

	# -------------------------------------------------------------------------
	# Limpieza de nodos creados
	# -------------------------------------------------------------------------
	dlg_event_1.queue_free()
	dlg_event_by_name.queue_free()
	dlg_event_isolated.queue_free()
	dlg_event_multi.queue_free()
	dlg_instance_b.queue_free()
	game_trigger_2.queue_free()
	dlg_item_evt.queue_free()

	print("\n===================================================================")
	print(">>> TODOS LOS TESTS DE EVENTOS DE DIÁLOGO PASARON CON ÉXITO 100% <<<")
	print("===================================================================\n")

	quit(0)
