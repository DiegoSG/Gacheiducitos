extends SceneTree

const PlayerScript = preload("res://src/minigames/mg_runner/mg_runner_player.gd")
const PickupScript = preload("res://src/minigames/mg_runner/mg_runner_pickup.gd")

func _init() -> void:
	print("\n--- TEST: MECÁNICAS DE RUNNER 2D (SIDE-SCROLLER) ---")
	
	# 1. Asegurar autoloads
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

	# 2. Cargar escena de RunnerLevel
	var runner_scene = load("res://src/minigames/mg_runner/mg_runner_level.tscn")
	assert(runner_scene != null, "mg_runner_level.tscn debe existir y cargar")
	var level = runner_scene.instantiate()
	root.add_child(level)
	await process_frame

	assert(level is MinigameBase, "RunnerLevel debe heredar de MinigameBase")
	print("[PASS] RunnerLevel instanciado e identificado como MinigameBase.")

	# 3. Validar Player y estados de colisión de pie vs agachado
	var player = level.get_node_or_null("RunnerPlayer")
	assert(player != null, "RunnerPlayer debe existir en el nivel")
	assert(player.stand_collision.disabled == false, "StandCollision debe estar activo de pie")
	assert(player.duck_collision.disabled == true, "DuckCollision debe estar deshabilitado de pie")
	print("[PASS] RunnerPlayer inicia en estado RUNNING con collider de pie activo.")

	# Simular agachado
	player._set_ducking_state()
	assert(player.stand_collision.disabled == true, "StandCollision debe deshabilitarse al agacharse")
	assert(player.duck_collision.disabled == false, "DuckCollision debe habilitarse al agacharse")
	print("[PASS] RunnerPlayer conmuta limpiamente colisionadores al agacharse.")

	# Restaurar de pie
	player._set_standing_state()
	assert(player.stand_collision.disabled == false, "StandCollision activo tras levantarse")
	assert(player.duck_collision.disabled == true, "DuckCollision deshabilitado tras levantarse")
	print("[PASS] RunnerPlayer restaura colisionador de pie correctamente.")

	# Validar ejecución de salto
	player.try_jump()
	assert(player.state == player.State.JUMPING, "El jugador debe estar en estado JUMPING tras saltar")
	assert(player.velocity_y == player.jump_velocity, "velocity_y debe coincidir con jump_velocity")
	print("[PASS] Ejecución directa de salto (try_jump) validada.")

	# 4. Validar patrones de monedas
	var world_objects = level.get_node_or_null("WorldObjects")
	assert(world_objects != null, "WorldObjects debe existir")
	
	# Probar patrón V_INVERTED (Arco de salto)
	var count_before = world_objects.get_child_count()
	level._spawn_coin_pattern(level.CoinPattern.V_INVERTED, 1000.0)
	var spawned_v_inv = world_objects.get_child_count() - count_before
	assert(spawned_v_inv == 5, "V_INVERTED debe generar exactamente 5 monedas en arco (obtenido: %d)" % spawned_v_inv)
	print("[PASS] Patrón V_INVERTED genera las 5 monedas parabólicas correctamente.")

	# Probar patrón LINE_4
	count_before = world_objects.get_child_count()
	level._spawn_coin_pattern(level.CoinPattern.LINE_4, 1000.0)
	var spawned_line_4 = world_objects.get_child_count() - count_before
	assert(spawned_line_4 == 4, "LINE_4 debe generar 4 monedas (obtenido: %d)" % spawned_line_4)
	print("[PASS] Patrón LINE_4 genera 4 monedas en línea correctamente.")

	# Probar patrón V_SHAPE
	count_before = world_objects.get_child_count()
	level._spawn_coin_pattern(level.CoinPattern.V_SHAPE, 1000.0)
	var spawned_v = world_objects.get_child_count() - count_before
	assert(spawned_v == 5, "V_SHAPE debe generar 5 monedas (obtenido: %d)" % spawned_v)
	print("[PASS] Patrón V_SHAPE genera 5 monedas en V correctamente.")

	# 5. Probar recolección de monedas e items al buffer de recompensas
	var initial_coins = level.coins_collected
	var test_coin = load("res://src/minigames/mg_runner/mg_runner_pickup.tscn").instantiate()
	test_coin.pickup_type = PickupScript.PickupType.COIN
	test_coin.item_id = "gold_coins"
	level.world_objects.add_child(test_coin)
	level._on_coin_collected(test_coin)
	assert(level.coins_collected == initial_coins + 1, "coins_collected debe incrementarse")
	assert(level.session_rewards.get("gold_coins") >= 1, "Debe acumularse gold_coins en session_rewards")
	print("[PASS] Recolección de monedas incrementa contador y acumula en session_rewards.")

	# Probar recolección de item aleatorio
	var test_item = load("res://src/minigames/mg_runner/mg_runner_pickup.tscn").instantiate()
	test_item.pickup_type = PickupScript.PickupType.RANDOM_ITEM
	test_item.item_id = "blue_potion"
	test_item.amount = 2
	level.world_objects.add_child(test_item)
	level._on_random_item_collected(test_item)
	assert(level.session_rewards.get("blue_potion") == 2, "Debe acumularse blue_potion x2 en session_rewards")
	print("[PASS] Recolección de ítem aleatorio añade el ítem al buffer de sesión.")

	# 6. Probar Condición de Victoria: Modo Distancia
	level.win_condition = level.WinCondition.DISTANCE
	level.target_value = 50.0
	level.current_distance = 60.0
	var win_detected = [false]
	level.game_finished.connect(func(s: bool, _r: Dictionary): if s: win_detected[0] = true)
	level._check_win_by_distance()
	assert(win_detected[0] == true, "Alcanzar la distancia meta debe disparar la victoria")
	print("[PASS] Condición de victoria por Distancia validada con éxito.")

	# 7. Probar Condición de Victoria: Modo Objeto Clave
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
	assert(level.target_object_spawned == true, "El objeto meta debe spawnear al superar el rango")
	
	# Buscar el pickup meta
	var found_target_pickup = null
	for child in level.world_objects.get_children():
		if child is PickupScript and child.is_victory_target:
			found_target_pickup = child
			break
	assert(found_target_pickup != null, "Debe existir un MG_RunnerPickup con is_victory_target = true")
	assert(found_target_pickup.item_id == "ancient_map", "El item_id debe coincidir con target_item_id")
	print("[PASS] Objeto clave de victoria spawnea en el mundo con propiedades y visual correcto.")

	# Simular captura del objeto meta
	var object_win = [false]
	level.game_finished.connect(func(s: bool, _r: Dictionary): if s: object_win[0] = true)
	level._on_target_pickup_collected(found_target_pickup)
	assert(object_win[0] == true, "Recoger el objeto meta debe completar el juego con victoria")
	assert(level.session_rewards.get("ancient_map") == 1, "ancient_map debe estar en session_rewards")
	print("[PASS] Captura del objeto clave otorga la recompensa y concluye con Victoria.")

	# Limpiar
	level.queue_free()
	print("\n>>> TODOS LOS TESTS DE MECÁNICAS DE RUNNER 2D PASARON SATISFACTORIAMENTE (100%) <<<\n")
	quit(0)
