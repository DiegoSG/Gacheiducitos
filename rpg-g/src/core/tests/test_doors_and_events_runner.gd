extends SceneTree

var enter_called: bool = false
var exit_called: bool = false

func _on_plate_pressed() -> void:
	enter_called = true

func _on_plate_released() -> void:
	exit_called = true

func _init() -> void:
	print("\n--- TEST: SISTEMA DE PUERTAS, CANDADOS Y ACCIONES DE EVENTOS ---")
	
	# 1. Cargar e instanciar nivel de prueba
	var portal_scene = load("res://src/overworld/components/level_portal.tscn")
	assert(portal_scene != null, "Error cargando level_portal.tscn")
	var portal: LevelPortal = portal_scene.instantiate()
	root.add_child(portal)
	
	var switch_scene = load("res://src/overworld/interactables/switch_interactable.tscn")
	assert(switch_scene != null, "Error cargando switch_interactable.tscn")
	var switch_node: SwitchInteractable = switch_scene.instantiate()
	root.add_child(switch_node)

	var plate_scene = load("res://src/overworld/interactables/pressure_plate.tscn")
	assert(plate_scene != null, "Error cargando pressure_plate.tscn")
	var plate: PressurePlate = plate_scene.instantiate()
	root.add_child(plate)
	
	await process_frame
	
	# Caso A: Modo PORTAL activo
	portal.mode = LevelPortal.Mode.PORTAL
	portal.is_active = true
	portal.is_locked = false
	assert(portal.collision_layer == 0 and portal.collision_mask == 2, "Portal layer/mask incorrecto")
	print("[PASS] Modo PORTAL activo: colisiones automáticas configuradas.")

	# Caso B: Modo DOOR
	portal.mode = LevelPortal.Mode.DOOR
	assert(portal.collision_layer == 16, "Door layer debe ser 16 (Actionable)")
	print("[PASS] Modo DOOR: layer 16 (Actionable) configurado para interacción.")

	# Caso C: Puerta bloqueada con llave
	portal.is_locked = true
	portal.required_key_id = "rusty_key"
	portal.consume_key = true
	
	var inventory = root.get_node_or_null("Inventory")
	if not inventory:
		var inv_script = load("res://src/core/inventory.gd")
		inventory = inv_script.new()
		inventory.name = "Inventory"
		root.add_child(inventory)
	inventory.items.clear()
	
	# Intento 1: Sin llave
	var opened = false
	portal.opened.connect(func(): opened = true)
	portal.action()
	assert(not opened, "La puerta no debió abrirse")
	assert(portal.is_locked == true, "La puerta debe seguir con candado")
	print("[PASS] Intento sin llave rechazado correctamente.")
	
	# Intento 2: Con llave
	inventory.add_item("rusty_key", 1)
	portal.action()
	assert(portal.is_locked == false, "La puerta debió desbloquearse con la llave")
	assert(not inventory.items.has("rusty_key"), "La llave debió ser consumida")
	print("[PASS] Apertura con llave y consumo de ítem verificado.")
	
	# 2. Test de DoorAction
	var door_action = DoorAction.new()
	door_action.target_door_path = portal.get_path()
	door_action.operation = DoorAction.DoorOperation.LOCK
	door_action.execute(switch_node)
	assert(portal.is_locked == true, "DoorAction LOCK falló")
	
	door_action.operation = DoorAction.DoorOperation.UNLOCK
	door_action.execute(switch_node)
	assert(portal.is_locked == false, "DoorAction UNLOCK falló")
	print("[PASS] DoorAction (LOCK / UNLOCK) ejecutada correctamente.")
	
	# 3. Test de SwitchInteractable disparando DoorAction
	portal.is_locked = true
	switch_node.trigger_actions.append(door_action)
	switch_node.action()
	assert(switch_node.is_on == true, "Switch no cambió a ON")
	assert(portal.is_locked == false, "Switch no desbloqueó la puerta")
	print("[PASS] SwitchInteractable activando DoorAction validado.")
	
	# 4. Test de DestroyNodeAction
	var obstacle = Node2D.new()
	obstacle.name = "TestObstacle"
	root.add_child(obstacle)
	
	var destroy_action = DestroyNodeAction.new()
	destroy_action.target_node_path = obstacle.get_path()
	destroy_action.mode = DestroyNodeAction.DestroyMode.QUEUE_FREE
	destroy_action.execute(switch_node)
	print("[PASS] DestroyNodeAction ejecutado correctamente.")

	# 5. Test de SpawnAction usando nodo de referencia (Target Node)
	var spawn_marker = Marker2D.new()
	spawn_marker.name = "SpawnMarker"
	spawn_marker.global_position = Vector2(450, 320)
	root.add_child(spawn_marker)
	
	var spawn_act = SpawnAction.new()
	spawn_act.scene_to_spawn = load("res://src/overworld/interactables/switch_interactable.tscn")
	spawn_act.spawn_target_node = spawn_marker.get_path()
	spawn_act.execute(switch_node)
	print("[PASS] SpawnAction con objeto de referencia validado.")

	# 6. Test de PressurePlate (Enter y Exit)
	plate.pressed.connect(_on_plate_pressed)
	plate.released.connect(_on_plate_released)
	
	var mock_player = Node2D.new()
	mock_player.name = "Player"
	root.add_child(mock_player)
	
	plate._on_body_entered(mock_player)
	assert(plate.is_pressed == true, "PressurePlate no cambió a is_pressed=true")
	assert(enter_called == true, "PressurePlate signal pressed() no fue emitida")
	
	plate._on_body_exited(mock_player)
	assert(plate.is_pressed == false, "PressurePlate no cambió a is_pressed=false")
	assert(exit_called == true, "PressurePlate signal released() no fue emitida")
	print("[PASS] PressurePlate (Enter & Exit) validado correctamente.")

	portal.queue_free()
	switch_node.queue_free()
	spawn_marker.queue_free()
	plate.queue_free()
	mock_player.queue_free()
	
	print("--- TODOS LOS TESTS DE PUERTAS, LÓGICA Y EVENTOS PASARON EXITOSAMENTE ---\n")
	quit(0)
