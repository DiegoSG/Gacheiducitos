extends SceneTree

func _init() -> void:
	print("\n--- TEST: SISTEMA Y FLUJO DE MINIJUEGOS (FRAMEWORK) ---")
	
	# 1. Asegurar singleton Inventory
	var inventory = root.get_node_or_null("Inventory")
	if not inventory:
		var inv_script = load("res://src/core/inventory.gd")
		inventory = inv_script.new()
		inventory.name = "Inventory"
		root.add_child(inventory)
	inventory.items.clear()

	# 2. Asegurar singleton GameManager
	var game_manager = root.get_node_or_null("GameManager")
	if not game_manager:
		var gm_script = load("res://src/core/game_manager.gd")
		game_manager = gm_script.new()
		game_manager.name = "GameManager"
		root.add_child(game_manager)

	await process_frame

	# 3. Validar instancia de DummyMinigame y clase MinigameBase
	var dummy_script = load("res://src/minigames/tests/dummy_minigame.gd")
	var dummy_scene = load("res://src/minigames/tests/dummy_minigame.tscn")
	assert(dummy_scene != null, "Error al cargar dummy_minigame.tscn")
	var dummy: Node2D = dummy_scene.instantiate()
	root.add_child(dummy)
	await process_frame

	assert(dummy is MinigameBase, "DummyMinigame debe heredar de MinigameBase")
	print("[PASS] DummyMinigame hereda correctamente de MinigameBase.")

	# 4. Probar acumulación de recompensas en sesión local
	dummy.add_reward("blue_potion", 2)
	dummy.add_reward("gold_coin", 10)
	assert(dummy.session_rewards["blue_potion"] == 2, "Recompensa de poción azul incorrecta")
	assert(dummy.session_rewards["gold_coin"] == 10, "Recompensa de monedas incorrecta")
	assert(not inventory.items.has("blue_potion"), "El inventario global NO debe tener los ítems antes de terminar")
	print("[PASS] Buffer de recompensas de sesión almacena ítems sin contaminar el inventario prematuramente.")

	# 5. Probar MinigameAction configurado
	var action_script = load("res://src/core/pipeline/actions/minigame_action.gd")
	var action = action_script.new()
	action.minigame_scene_path = "res://src/minigames/tests/dummy_minigame.tscn"
	action.win_level_path = "res://src/minigames/tests/test_minigame_flow.tscn"
	action.win_spawn_id = "spawn_win"
	action.lose_level_path = "res://src/minigames/tests/test_minigame_flow.tscn"
	action.lose_spawn_id = "spawn_lose"
	action.config = {"difficulty": "hard"}

	var dummy_trigger = Node.new()
	root.add_child(dummy_trigger)
	action.execute(dummy_trigger)

	assert(game_manager.minigame_config.get("win_level_path") == "res://src/minigames/tests/test_minigame_flow.tscn", "win_level_path no inyectado")
	assert(game_manager.minigame_config.get("win_spawn_id") == "spawn_win", "win_spawn_id no inyectado")
	assert(game_manager.minigame_config.get("lose_spawn_id") == "spawn_lose", "lose_spawn_id no inyectado")
	print("[PASS] MinigameAction inyecta correctamente las rutas y spawns de victoria/derrota al GameManager.")

	# 6. Probar finalización con Victoria: transferir ítems y verificar inventario
	var win_results = {"items": {"blue_potion": 3, "rusty_key": 1}}
	game_manager._minigame_win_path = "res://src/minigames/tests/test_minigame_flow.tscn"
	game_manager._minigame_win_spawn_id = "spawn_win"
	
	# Simular complete_minigame
	game_manager.complete_minigame(true, win_results)
	await process_frame

	assert(inventory.items.get("blue_potion") == 3, "El inventario global debe contener 3 blue_potion tras ganar")
	assert(inventory.items.get("rusty_key") == 1, "El inventario global debe contener 1 rusty_key tras ganar")
	print("[PASS] complete_minigame(true) transfiere satisfactoriamente todos los ítems al Inventario Global.")

	# Limpiar
	dummy.queue_free()
	dummy_trigger.queue_free()
	print("\n>>> TODOS LOS TESTS DE MINIGAME FRAMEWORK PASARON SATISFACTORIAMENTE (100%) <<<\n")
	quit(0)
