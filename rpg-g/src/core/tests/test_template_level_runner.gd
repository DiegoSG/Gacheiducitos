extends SceneTree

const TEMPLATE_SCENE = preload("res://src/overworld/levels/template_level.tscn")
const PLAYER_SCENE = preload("res://src/overworld/player/player.tscn")
const BoundedCamera = preload("res://src/overworld/components/bounded_camera.gd")

func _init() -> void:
	print("\n--- TEST: VALIDACIÓN DE TEMPLATE LEVEL Y PLAYER AUTÓNOMO ---")
	
	# Autoloads mínimos si se requieren
	var inv = root.get_node_or_null("Inventory")
	if not inv:
		var inv_script = load("res://src/core/inventory.gd")
		inv = inv_script.new()
		inv.name = "Inventory"
		root.add_child(inv)
		
	var item_db = root.get_node_or_null("ItemDatabase")
	if not item_db:
		var db_script = load("res://src/core/item_database.gd")
		item_db = db_script.new()
		item_db.name = "ItemDatabase"
		root.add_child(item_db)
		
	await process_frame
	
	# ----------------------------------------------------
	# Test 1: Instanciación limpia de TemplateLevel
	# ----------------------------------------------------
	var level = TEMPLATE_SCENE.instantiate()
	root.add_child(level)
	await process_frame
	
	assert(level != null, "TemplateLevel debe instanciarse correctamente")
	var wbm = level.get_node_or_null("WorldBoundaryManager")
	var env = level.get_node_or_null("Environment")
	var spawn_pts = level.get_node_or_null("SpawnPoints")
	var entities = level.get_node_or_null("Entities")
	var portals = level.get_node_or_null("Portals")
	
	assert(wbm != null, "WorldBoundaryManager debe existir en TemplateLevel")
	assert(env != null, "Environment debe existir en TemplateLevel")
	assert(spawn_pts != null, "SpawnPoints debe existir en TemplateLevel")
	assert(entities != null, "Entities debe existir en TemplateLevel")
	assert(portals != null, "Portals debe existir en TemplateLevel")
	
	# Verificar capas limpias de TileMapLayer
	var ground = env.get_node_or_null("GroundLayer")
	var detail = env.get_node_or_null("DetailLayer")
	var props = env.get_node_or_null("PropsLayer")
	assert(ground != null and detail != null and props != null, "Las 3 capas de TileMapLayer deben existir")
	assert(ground.tile_set != null, "GroundLayer debe tener asignado core_tileset.tres")
	
	# Verificar punto de spawn por defecto
	var spawn_start = spawn_pts.get_node_or_null("SpawnStart")
	assert(spawn_start != null, "SpawnStart debe existir en SpawnPoints")
	assert(spawn_start.arrival_id == "start", "arrival_id de SpawnStart debe ser 'start'")
	print("[PASS] Test 1: Estructura de TemplateLevel limpia y verificada.")
	
	# ----------------------------------------------------
	# Test 2: 'Tirarle el Player' y verificar funcionamiento automático
	# ----------------------------------------------------
	var player = PLAYER_SCENE.instantiate()
	entities.add_child(player)
	player.global_position = spawn_start.global_position
	await process_frame
	await process_frame
	
	assert(player != null, "Player debe instanciarse")
	assert(player.is_in_group("player"), "Player debe estar en grupo 'player'")
	
	# Verificar que el Player tiene Camera2D / BoundedCamera
	var cam = player.get_node_or_null("Camera2D")
	assert(cam != null, "Player debe contar con su propia Camera2D integrada")
	assert(cam is BoundedCamera, "La cámara del Player debe ser BoundedCamera")
	
	# Verificar que la cámara se sincronizó automáticamente con WorldBoundaryManager
	var bounds = wbm.get_level_bounds()
	assert(cam.limit_right == int(bounds.x), "Límite derecho de la cámara debe coincidir con el nivel")
	assert(cam.limit_bottom == int(bounds.y), "Límite inferior de la cámara debe coincidir con el nivel")
	assert(cam.limit_left == 0 and cam.limit_top == 0, "Límites superior e izquierdo deben ser 0")
	print("[PASS] Test 2: Player soltado en el nivel cuenta con BoundedCamera sincronizada automáticamente.")
	
	# ----------------------------------------------------
	# Test 3: Verificación de colisiones perimetrales (WorldBoundaries)
	# ----------------------------------------------------
	var static_body = wbm.get_node_or_null("WorldBoundaries")
	assert(static_body != null, "WorldBoundaryManager debe haber generado los muros perimetrales estáticos")
	assert(static_body.get_child_count() == 4, "Deben existir 4 colisionadores perimetrales (top, bottom, left, right)")
	print("[PASS] Test 3: Muros perimetrales invisibles generados correctamente.")
	
	# ----------------------------------------------------
	# Test 4: Verificación de PlayerHUD integrado
	# ----------------------------------------------------
	var hud = player.get_node_or_null("PlayerHUD")
	assert(hud != null, "Player debe contener su PlayerHUD")
	var toast_container = hud.get_node_or_null("ToastContainer")
	assert(toast_container != null, "PlayerHUD debe contener ToastContainer para notificaciones de loot")
	print("[PASS] Test 4: PlayerHUD y ToastContainer integrados en el Player funcionando.")
	
	print("\n>>> TODOS LOS TESTS DE TEMPLATE LEVEL Y PLAYER AUTÓNOMO PASARON AL 100% <<<\n")
	level.queue_free()
	quit(0)
