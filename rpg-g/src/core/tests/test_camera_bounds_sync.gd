extends SceneTree

func _init() -> void:
	print("--- TEST: WORLD BOUNDARY AND CAMERA LIMITS SYNC ---")
	
	var scene_res = load("res://src/overworld/levels/level_01.tscn")
	assert(scene_res != null, "Error loading level_01.tscn")
	var scene = scene_res.instantiate()
	root.add_child(scene)
	await process_frame
	
	var wbm = scene.get_node_or_null("WorldBoundaryManager")
	assert(wbm != null, "WorldBoundaryManager not found in level_01")
	
	var player = scene.get_node("Player")
	var camera = player.get_node("Camera2D")
	assert(camera != null, "Camera2D not found in Player")
	
	print("[INFO] Initial camera limits: right=", camera.limit_right, ", bottom=", camera.limit_bottom)
	assert(camera.limit_right == int(wbm.width), "initial limit_right does not match")
	assert(camera.limit_bottom == int(wbm.height), "initial limit_bottom does not match")
	print("[PASS] Initial sync correct.")
	
	# Change width and height at runtime
	print("[INFO] Changing WorldBoundaryManager dimensions to width=1800, height=900...")
	wbm.width = 1800.0
	wbm.height = 900.0
	
	print("[INFO] New camera limits: right=", camera.limit_right, ", bottom=", camera.limit_bottom)
	assert(camera.limit_right == 1800, "limit_right was not updated after changing width")
	assert(camera.limit_bottom == 900, "limit_bottom was not updated after changing height")
	print("[PASS] Signal-driven dynamic sync correct.")
	
	scene.queue_free()
	print("--- SYNC TEST PASSED SUCCESSFULLY ---")
	quit(0)
