extends SceneTree

func _init() -> void:
	print("--- TEST: SISTEMA DE PORTALES Y PUNTOS DE LLEGADA ---")
	
	# 1. Probar carga de Sala A
	var room_a_res = ResourceLoader.load("res://src/overworld/levels/test_portal_room_a.tscn")
	assert(room_a_res != null, "Error al cargar test_portal_room_a.tscn")
	var room_a = room_a_res.instantiate()
	root.add_child(room_a)
	
	print("[PASS] Escena Room A instanciada correctamente.")
	
	# Verificar portales y arrival points en Room A
	var p1 = room_a.get_node_or_null("Portal1")
	var p2 = room_a.get_node_or_null("Portal2")
	var drop = room_a.get_node_or_null("DropPointA")
	
	assert(p1 != null, "Portal1 no encontrado")
	assert(p2 != null, "Portal2 no encontrado")
	assert(drop != null, "DropPointA no encontrado")
	
	assert(p1.exit_id == "1", "Portal1 exit_id mismatch")
	assert(p1.arrival_id == "1", "Portal1 arrival_id mismatch")
	assert(p2.exit_id == "2", "Portal2 exit_id mismatch")
	assert(drop.arrival_id == "drop_point_a", "DropPointA arrival_id mismatch")
	
	print("[PASS] Propiedades de portales en Room A validadas.")
	
	# Verificar get_spawn_position
	var pos1 = p1.get_spawn_position()
	print("[INFO] Portal1 spawn pos: ", pos1)
	assert(pos1 != Vector2.ZERO, "Portal1 spawn position inválida")
	
	var drop_pos = drop.get_spawn_position()
	print("[INFO] DropPointA spawn pos: ", drop_pos)
	assert(drop_pos == drop.global_position, "DropPointA spawn position mismatch")
	
	# Probar advertencias de duplicados
	var p_dup = p1.duplicate()
	room_a.add_child(p_dup)
	p_dup.arrival_id = "1"
	var warnings = p_dup._get_configuration_warnings()
	print("[INFO] Warnings en duplicado: ", warnings)
	assert(warnings.size() > 0, "No se detectó advertencia de arrival_id duplicado")
	print("[PASS] Validación de arrival_id duplicado funciona correctamente.")
	
	room_a.queue_free()
	
	# 2. Probar carga de Sala B
	var room_b_res = ResourceLoader.load("res://src/overworld/levels/test_portal_room_b.tscn")
	assert(room_b_res != null, "Error al cargar test_portal_room_b.tscn")
	var room_b = room_b_res.instantiate()
	root.add_child(room_b)
	print("[PASS] Escena Room B instanciada correctamente.")
	
	print("--- TODOS LOS TESTS PASARON EXITOSAMENTE ---")
	quit(0)
