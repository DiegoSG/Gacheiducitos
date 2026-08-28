extends SceneTree

func _init() -> void:
	print("--- TEST: SINCRONIZACIÓN DE LÍMITES WORLD BOUNDARY Y CÁMARA ---")
	
	var scene_res = load("res://src/overworld/levels/prototype_template.tscn")
	assert(scene_res != null, "Error al cargar prototype_template.tscn")
	var scene = scene_res.instantiate()
	root.add_child(scene)
	await process_frame
	
	var wbm = scene.get_node_or_null("WorldBoundaryManager")
	assert(wbm != null, "WorldBoundaryManager no encontrado en prototype_template")
	
	var player = scene.get_node("Player")
	var camera = player.get_node("Camera2D")
	assert(camera != null, "Camera2D no encontrada en Player")
	
	print("[INFO] Límites iniciales de la cámara: right=", camera.limit_right, ", bottom=", camera.limit_bottom)
	assert(camera.limit_right == int(wbm.width), "limit_right inicial no coincide")
	assert(camera.limit_bottom == int(wbm.height), "limit_bottom inicial no coincide")
	print("[PASS] Sincronización inicial correcta.")
	
	# Modificar ancho y alto en runtime
	print("[INFO] Modificando dimensiones de WorldBoundaryManager a width=1800, height=900...")
	wbm.width = 1800.0
	wbm.height = 900.0
	
	print("[INFO] Nuevos límites de la cámara: right=", camera.limit_right, ", bottom=", camera.limit_bottom)
	assert(camera.limit_right == 1800, "limit_right no se actualizó tras cambiar width")
	assert(camera.limit_bottom == 900, "limit_bottom no se actualizó tras cambiar height")
	print("[PASS] Sincronización dinámica por señal correcta.")
	
	scene.queue_free()
	print("--- TEST DE SINCRONIZACIÓN PASÓ EXITOSAMENTE ---")
	quit(0)
