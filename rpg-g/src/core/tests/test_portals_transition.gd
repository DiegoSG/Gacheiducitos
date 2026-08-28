extends SceneTree

func _init() -> void:
	print("--- TEST: SIMULACIÓN DE TRANSICIÓN DE NIVELES CON GAMEMANAGER ---")
	
	# Instanciar GameManager si no está en árbol
	var gm_res = load("res://src/core/game_manager.gd")
	var gm = Node.new()
	gm.set_script(gm_res)
	gm.name = "GameManager"
	root.add_child(gm)
	
	# Cargar Sala A inicialmente
	var room_a_res = load("res://src/overworld/levels/test_portal_room_a.tscn")
	var room_a = room_a_res.instantiate()
	root.add_child(room_a)
	current_scene = room_a
	gm.current_scene = room_a
	await process_frame
	
	var player = room_a.get_node("Player")
	print("[INFO] Posición inicial del jugador en Sala A: ", player.global_position)
	
	# Ejecutar cambio de nivel a Sala B con llegada a Portal 2 (arrival_id = "2")
	print("[INFO] Ejecutando change_level hacia Sala B con arrival_id = '2'...")
	gm.change_level("res://src/overworld/levels/test_portal_room_b.tscn", "2")
	await gm.level_changed
	
	var current_level = gm.current_scene
	assert("test_portal_room_b" in current_level.scene_file_path, "El nivel actual debería ser test_portal_room_b")
	
	var player_in_b = current_level.get_node("Player")
	var portal2_in_b = current_level.get_node("Portal2")
	var expected_spawn_pos = portal2_in_b.get_spawn_position()
	
	print("[INFO] Posición del jugador en Sala B: ", player_in_b.global_position)
	print("[INFO] Posición esperada de spawn: ", expected_spawn_pos)
	
	assert(player_in_b.global_position.distance_to(expected_spawn_pos) < 1.0, "El jugador no apareció en el spawn point de Portal2 en Sala B")
	print("[PASS] Transición bidireccional hacia Portal 2 completada exitosamente.")
	
	# Ejecutar cambio de nivel a Sala A hacia DropPointA (arrival_id = "drop_point_a")
	print("[INFO] Ejecutando change_level hacia Sala A con arrival_id = 'drop_point_a'...")
	gm.change_level("res://src/overworld/levels/test_portal_room_a.tscn", "drop_point_a")
	await gm.level_changed
	
	current_level = gm.current_scene
	print("[DEBUG] current_level: ", current_level, " path: ", current_level.scene_file_path if current_level else "null", " name: ", current_level.name if current_level else "null")
	assert(current_level != null and "test_portal_room_a" in current_level.scene_file_path, "El nivel actual debería ser test_portal_room_a")
	
	var player_in_a = current_level.get_node("Player")
	var drop_point = current_level.get_node("DropPointA")
	var expected_drop_pos = drop_point.get_spawn_position()
	
	print("[INFO] Posición del jugador en DropPoint: ", player_in_a.global_position)
	print("[INFO] Posición esperada en DropPoint: ", expected_drop_pos)
	
	assert(player_in_a.global_position.distance_to(expected_drop_pos) < 1.0, "El jugador no apareció en el DropPointA")
	print("[PASS] Transición unidireccional hacia ArrivalSpawnPoint completada exitosamente.")
	
	print("--- TODOS LOS TESTS DE TRANSICIÓN PASARON EXITOSAMENTE ---")
	quit(0)
