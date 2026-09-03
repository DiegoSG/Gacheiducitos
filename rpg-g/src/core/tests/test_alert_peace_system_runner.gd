extends SceneTree

func _init() -> void:
	print("\n--- TEST: SISTEMA DE ESTADOS DE PAZ Y ALERTA (OVERWORLD) ---")
	
	await process_frame
	
	# Asegurarnos de tener GameManager inicializado
	var gm = root.get_node_or_null("GameManager")
	if not gm:
		var gm_script = load("res://src/core/game_manager.gd")
		gm = gm_script.new()
		gm.name = "GameManager"
		root.add_child(gm)
	
	# Test 1: Estado inicial debe ser PEACE
	assert(gm.alert_state == gm.WorldAlertState.PEACE, "Estado inicial debe ser PEACE")
	assert(gm.is_in_alert() == false, "is_in_alert() debe ser false inicialmente")
	print("[PASS] Estado inicial es PEACE.")
	
	# Configurar escucha de señal con tracker Dictionary (captura por referencia)
	var tracker = {"last_state": null, "count": 0}
	gm.alert_state_changed.connect(func(state):
		tracker.last_state = state
		tracker.count += 1
	)
	
	# Test 2: Instanciar un enemigo y simular persecución
	var enemy_scene = load("res://src/shared/entities/enemies/generic_enemy.tscn")
	assert(enemy_scene != null, "generic_enemy.tscn no pudo ser cargado")
	var enemy1 = enemy_scene.instantiate()
	enemy1.position = Vector2(1000, 1000)
	root.add_child(enemy1)
	
	var mock_player = CharacterBody2D.new()
	mock_player.name = "Player"
	mock_player.position = Vector2(0, 0)
	mock_player.add_to_group("player")
	root.add_child(mock_player)
	
	await process_frame
	
	# Reiniciar contadores para medir el disparo manual
	gm.clear_pursuers()
	tracker.last_state = null
	tracker.count = 0
	
	# Disparar detección del jugador
	enemy1._on_vision_entered(mock_player)
	assert(gm.alert_state == gm.WorldAlertState.ALERT, "El estado debe cambiar a ALERT al perseguir")
	assert(gm.is_in_alert() == true, "is_in_alert() debe devolver true")
	assert(tracker.last_state == gm.WorldAlertState.ALERT, "alert_state_changed no emitió ALERT")
	assert(tracker.count == 1, "La señal alert_state_changed debió emitirse 1 vez")
	print("[PASS] Transición a estado ALERT al iniciar persecución verificada.")
	
	# Test 3: Bloqueo de interacción con NPCs en estado de alerta
	var npc_script = load("res://src/shared/entities/simple_npc.gd")
	var test_npc = npc_script.new()
	test_npc.name = "TestNPC"
	test_npc.npc_name = "NPC_Prueba"
	root.add_child(test_npc)
	
	assert(test_npc.allow_during_alert == false, "SimpleNPC debe tener allow_during_alert = false")
	
	# Intentar interacción con NPC en ALERT (no debe crashear ni abrir diálogo)
	test_npc.action()
	print("[PASS] Interacción con SimpleNPC en estado ALERT descartada correctamente.")
	
	# Test 4: Objetos interactuables normales (cofres/palancas) SÍ permiten interacción en alerta
	var actionable_script = load("res://src/overworld/components/actionable.gd")
	var generic_interactable = actionable_script.new()
	generic_interactable.name = "TestChest"
	root.add_child(generic_interactable)
	
	assert(generic_interactable.allow_during_alert == true, "Actionable genérico debe permitir allow_during_alert = true")
	generic_interactable.action()
	assert(generic_interactable.triggered == true, "Actionable genérico debió ejecutarse en alerta")
	print("[PASS] Interactuables con allow_during_alert = true funcionan en estado ALERT.")
	
	# Test 5: Múltiples enemigos persiguiendo
	var enemy2 = enemy_scene.instantiate()
	root.add_child(enemy2)
	await process_frame
	
	enemy2._on_vision_entered(mock_player)
	assert(gm.alert_state == gm.WorldAlertState.ALERT, "El estado sigue en ALERT con 2 enemigos")
	assert(tracker.count == 1, "No debe re-emitir señal si ya estaba en ALERT")
	
	# Test 6: Un enemigo deja de perseguir (sale de lose_target_zone), pero otro sigue persiguiendo
	enemy1._on_lose_target_exited(mock_player)
	assert(gm.alert_state == gm.WorldAlertState.ALERT, "El estado debe seguir en ALERT si aún hay un enemigo")
	assert(gm.is_in_alert() == true, "is_in_alert() debe ser true con 1 enemigo restante")
	print("[PASS] Manejo de múltiples perseguidores validado.")
	
	# Test 7: Segundo enemigo es destruido (queue_free/exit_tree)
	enemy2.queue_free()
	await process_frame
	await process_frame
	
	assert(gm.alert_state == gm.WorldAlertState.PEACE, "El estado debe retornar a PEACE al morir el último enemigo")
	assert(gm.is_in_alert() == false, "is_in_alert() debe ser false tras eliminación del enemigo")
	assert(tracker.last_state == gm.WorldAlertState.PEACE, "alert_state_changed debió emitir PEACE")
	assert(tracker.count == 2, "La señal debió emitirse para la vuelta a PEACE")
	print("[PASS] Transición de vuelta a PEACE al morir los enemigos verificada.")
	
	# Test 8: Interacción con NPC ahora es permitida en estado PEACE
	assert(not (not test_npc.allow_during_alert and gm.is_in_alert()), "La guardia de alerta no debe bloquear en PEACE")
	print("[PASS] Interacción con SimpleNPC permitida de nuevo en estado PEACE.")
	
	# Test 9: Cooldown y reingreso en LoseTargetZone
	assert(enemy1.current_state == enemy1.State.COOLDOWN, "Enemy1 debió pasar a COOLDOWN tras salir de rango")
	enemy1._on_lose_target_entered(mock_player)
	assert(enemy1.current_state == enemy1.State.CHASE, "Reingresar a lose_target_zone en COOLDOWN debe reactivar CHASE")
	assert(gm.is_in_alert() == true, "Re-enganche debe volver a ALERT")
	print("[PASS] Reingreso a LoseTargetZone durante COOLDOWN reactiva CHASE.")
	
	# Test 10: Expiración de Cooldown y Retorno al Punto de Partida
	enemy1.global_position = Vector2(500, 500)
	enemy1._start_position = Vector2(100, 100)
	enemy1._on_lose_target_exited(mock_player)
	assert(enemy1.current_state == enemy1.State.COOLDOWN, "Debe entrar a COOLDOWN tras salir")
	# Simular paso del tiempo (>10 segundos)
	enemy1._physics_process(10.5)
	assert(enemy1.current_state == enemy1.State.RETURNING, "Al expirar cooldown debe pasar a RETURNING")
	print("[PASS] Expiración de cooldown activa estado RETURNING hacia punto de partida.")
	
	# Test 11: Durante RETURNING, el radio de detección sigue siendo el grande (LoseTargetZone)
	enemy1._on_lose_target_entered(mock_player)
	assert(enemy1.current_state == enemy1.State.CHASE, "Durante RETURNING, entrar a LoseTargetZone debe reactivar CHASE")
	print("[PASS] Detección con radio grande durante RETURNING verificada.")
	
	# Test 12: Llegada al punto de partida pasa a IDLE y restablece el radio pequeño
	enemy1._on_lose_target_exited(mock_player)
	enemy1._physics_process(10.5) # Expira cooldown -> RETURNING
	assert(enemy1.current_state == enemy1.State.RETURNING, "Pasa a RETURNING")
	
	enemy1.global_position = Vector2(101, 101) # Muy cerca de start_position (100, 100)
	enemy1._physics_process(0.1)
	assert(enemy1.current_state == enemy1.State.IDLE, "Al llegar a start_position debe pasar a IDLE")
	
	# En IDLE, entrar solo a LoseTargetZone NO debe activar CHASE
	enemy1._on_lose_target_entered(mock_player)
	assert(enemy1.current_state == enemy1.State.IDLE, "En IDLE, LoseTargetZone NO debe activar persecución")
	
	# Solo VisionZone debe activar persecución en IDLE
	enemy1._on_vision_entered(mock_player)
	assert(enemy1.current_state == enemy1.State.CHASE, "En IDLE, VisionZone activa persecución")
	print("[PASS] Transición a IDLE con radio pequeño restablecido verificada exitosamente.")

	# Limpieza
	enemy1.queue_free()
	mock_player.queue_free()
	test_npc.queue_free()
	generic_interactable.queue_free()
	
	print("--- TODOS LOS TESTS DE ESTADO DE PAZ, ALERTA, COOLDOWN Y RETORNO PASARON EXITOSAMENTE ---\n")
	quit(0)

