extends Node

# Singleton to manage game state and scene transitions

enum WorldAlertState {
	PEACE,
	ALERT
}

signal level_changed(target_level_path: String, spawn_id: String)
signal alert_state_changed(new_state: WorldAlertState)
signal game_event(event_name: String, event_data: Variant)

func trigger_event(event_name: String, event_data: Variant = null) -> void:
	print("[GameManager] trigger_event: '%s'" % event_name)
	game_event.emit(event_name, event_data)

const FADER_SCENE: PackedScene = preload("res://src/ui/screen_fader.tscn")

var current_scene: Node = null
var previous_scene_path: String = ""
var player_return_position: Vector2 = Vector2.ZERO

# Estado de alerta / persecución
var alert_state: WorldAlertState = WorldAlertState.PEACE
var _active_pursuers: Array[Node] = []

# Configuración de minijuego (para debug y persistencia)
var minigame_config: Dictionary = {}
var current_level_seed: int = -1

var _minigame_win_path: String = ""
var _minigame_win_spawn_id: String = ""
var _minigame_lose_path: String = ""
var _minigame_lose_spawn_id: String = ""
var _is_changing_level: bool = false

# Checkpoint y Respawn
var active_checkpoint_scene_path: String = ""
var active_checkpoint_player_snapshot: Dictionary = {}
var level_entry_world_state_snapshot: Dictionary = {}
var is_player_dead: bool = false

signal player_respawned

func _ready() -> void:
	var root: Window = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)
	if is_instance_valid(current_scene):
		register_level_entry(current_scene.scene_file_path, current_scene)

func load_minigame(minigame_path: String, player_pos: Vector2 = Vector2.ZERO) -> void:
	if is_instance_valid(current_scene):
		# Solo guardar la escena previa si NO es ya parte de una partida de minijuego
		# (Para que las escenas de prueba o el Overworld se preserven correctamente)
		if not (current_scene is MinigameBase):
			previous_scene_path = current_scene.scene_file_path
			player_return_position = player_pos
			print("GameManager: Saved return path: ", previous_scene_path)
			
	# Extraer rutas de retorno de la config si existen, o usar default
	_minigame_win_path = minigame_config.get("win_level_path", previous_scene_path)
	_minigame_win_spawn_id = minigame_config.get("win_spawn_id", "")
	_minigame_lose_path = minigame_config.get("lose_level_path", previous_scene_path)
	_minigame_lose_spawn_id = minigame_config.get("lose_spawn_id", "")
		
	call_deferred("_deferred_load_minigame", minigame_path)

func _deferred_load_minigame(path: String) -> void:
	if path.is_empty():
		push_error("GameManager: Cannot load empty minigame path.")
		return

	var s = ResourceLoader.load(path)
	if not s:
		push_error("GameManager: Failed to load scene: %s" % path)
		return

	if is_instance_valid(current_scene):
		current_scene.queue_free()
	
	clear_pursuers()
	current_scene = s.instantiate()
	get_tree().root.add_child(current_scene)
	get_tree().current_scene = current_scene
	
	# Conexión explícita e infalible de la señal game_finished
	if current_scene.has_signal("game_finished"):
		if not current_scene.game_finished.is_connected(complete_minigame):
			current_scene.game_finished.connect(complete_minigame)
			print("GameManager: Conectado con éxito a 'game_finished' de ", current_scene.name)
	
	# If returning to Overworld, restore player position
	if path == previous_scene_path and player_return_position != Vector2.ZERO:
		if current_scene.has_node("Player"):
			current_scene.get_node("Player").position = player_return_position

func complete_minigame(success: bool, results: Dictionary = {}) -> void:
	print("GameManager: complete_minigame called. Success: ", success)
	
	# Guardar items para animar su llegada en el HUD del Overworld
	var pending_items: Dictionary = {}
	if results.has("items"):
		pending_items = results["items"]
		var inventory: Node = get_node_or_null("/root/Inventory")
		if not inventory and get_tree() and get_tree().root:
			inventory = get_tree().root.get_node_or_null("Inventory")
			
		if inventory and inventory.has_method("add_item"):
			for item_id in pending_items:
				inventory.add_item(item_id, pending_items[item_id])
			
	# Determinar a dónde ir y qué spawn usar
	var target_scene = _minigame_win_path if success else _minigame_lose_path
	var target_spawn_id = _minigame_win_spawn_id if success else _minigame_lose_spawn_id
	
	# Fallback si por alguna razón están vacíos
	if target_scene.is_empty():
		target_scene = previous_scene_path if not previous_scene_path.is_empty() else "res://src/overworld/levels/Lvl01.tscn"
		
	# Usar el sistema de transiciones con fader
	await change_level(target_scene, target_spawn_id)
	
	# Si obtuvimos items del minijuego, animar su llegada en el HUD
	if not pending_items.is_empty():
		var item_db: Node = get_node_or_null("/root/ItemDatabase")
		if item_db:
			for item_id: String in pending_items:
				var data: ItemData = item_db.get_item(item_id)
				if data and LootFeedbackManager.instance:
					var center_screen: Vector2 = get_viewport().get_visible_rect().size * 0.5
					LootFeedbackManager.trigger_screen_loot(data, center_screen, pending_items[item_id])

func return_to_overworld() -> void:
	print("GameManager: return_to_overworld called")
	# Retrocompatibilidad temporal para los minijuegos no actualizados aún
	var target_scene: String = previous_scene_path if previous_scene_path != "" else "res://src/overworld/levels/Lvl01.tscn"
	print("GameManager: target_scene = ", target_scene)
	change_level(target_scene)

func change_level(target_level_path: String, spawn_id: String = "", exact_pos: Vector2 = Vector2.ZERO, use_exact: bool = false) -> void:
	if _is_changing_level:
		print("GameManager: Scene transition already in progress. Ignoring request for: ", target_level_path)
		return
	if target_level_path.is_empty():
		return

	_is_changing_level = true
		
	var fader: ScreenFader = FADER_SCENE.instantiate()
	get_tree().root.add_child(fader)
	
	# Desactivar movimiento del jugador si existe
	if is_instance_valid(current_scene) and current_scene.has_node("Player"):
		current_scene.get_node("Player").set_physics_process(false)
		
	await fader.fade_out(0.4)

	var next_scene_resource = ResourceLoader.load(target_level_path)
	if not next_scene_resource:
		push_error("GameManager: Failed to load target level: %s" % target_level_path)
		await fader.fade_in(0.2)
		fader.queue_free()
		_is_changing_level = false
		if is_instance_valid(current_scene) and current_scene.has_node("Player"):
			current_scene.get_node("Player").set_physics_process(true)
		return

	if is_instance_valid(current_scene):
		current_scene.queue_free()
		
	clear_pursuers()
	current_scene = next_scene_resource.instantiate()
	get_tree().root.add_child(current_scene)
	get_tree().current_scene = current_scene
	
	# Posicionar al jugador en el spawn deseado
	if current_scene.has_node("Player"):
		var player: Node2D = current_scene.get_node("Player") as Node2D
		if use_exact:
			player.global_position = exact_pos
		elif not spawn_id.is_empty():
			var found_spawn: bool = false
			# 1. Buscar en nodos del grupo arrival_points (LevelPortal y ArrivalSpawnPoint) dentro de la nueva escena
			for arrival_node in get_tree().get_nodes_in_group("arrival_points"):
				if is_instance_valid(arrival_node) and current_scene.is_ancestor_of(arrival_node):
					if "arrival_id" in arrival_node and str(arrival_node.arrival_id) == str(spawn_id):
						if arrival_node.has_method("get_spawn_position"):
							player.global_position = arrival_node.get_spawn_position()
						else:
							player.global_position = arrival_node.global_position
						found_spawn = true
						break
			# 2. Fallback de compatibilidad para escenas heredadas (SpawnPoints/ID)
			if not found_spawn and current_scene.has_node("SpawnPoints/" + spawn_id):
				var spawn_node = current_scene.get_node("SpawnPoints/" + spawn_id)
				player.global_position = spawn_node.global_position
				found_spawn = true
				
		# Reubicar y reiniciar suavizado de la cámara antes del fade in
		_snap_scene_cameras(current_scene)
		player.set_physics_process(true)
		# TODO: Animación de salida (el personaje aparece en el portal y se desplaza automáticamente hacia el arrival point)
		
	# Esperar un fotograma para asentar transformaciones y límites de cámara antes de aclarar pantalla
	await get_tree().process_frame
		
	await fader.fade_in(0.4)
	fader.queue_free()
	_is_changing_level = false
	register_level_entry(target_level_path, current_scene)
	level_changed.emit(target_level_path, spawn_id)

func register_level_entry(scene_path: String, scene_node: Node) -> void:
	if not is_instance_valid(scene_node):
		return
	
	# Respaldar estado del mundo al inicio de este nivel (para revertir si muere aquí)
	var ws: Node = get_node_or_null("/root/WorldStateManager")
	if ws and ws.has_method("create_snapshot"):
		level_entry_world_state_snapshot = ws.create_snapshot()
		print("[GameManager] WorldState snapshot registrado para el nivel: ", scene_path)
	
	# Verificar si este nivel es Checkpoint (o si es el primer nivel visitado y aún no hay checkpoint)
	var is_checkpoint: bool = false
	if scene_node.has_node("CheckpointLevel") or _find_node_by_class(scene_node, "CheckpointLevel") != null:
		is_checkpoint = true
	elif active_checkpoint_scene_path.is_empty() and not scene_path.is_empty():
		# Primer nivel actúa como checkpoint por defecto
		is_checkpoint = true
		
	if is_checkpoint and not scene_path.is_empty():
		active_checkpoint_scene_path = scene_path
		_capture_checkpoint_player_snapshot()
		print("[GameManager] Checkpoint activo actualizado a: ", active_checkpoint_scene_path)

func _find_node_by_class(root: Node, class_str: String) -> Node:
	if root.get_class() == class_str or root.is_class(class_str) or (root.get_script() and root.get_script().get_global_name() == class_str):
		return root
	for child in root.get_children():
		var found = _find_node_by_class(child, class_str)
		if found:
			return found
	return null

func _capture_checkpoint_player_snapshot() -> void:
	var stats: Node = get_node_or_null("/root/PlayerStats")
	var inv: Node = get_node_or_null("/root/Inventory")
	var stats_data: Dictionary = stats.create_snapshot() if stats and stats.has_method("create_snapshot") else {}
	var inv_data: Dictionary = inv.create_snapshot() if inv and inv.has_method("create_snapshot") else {}
	active_checkpoint_player_snapshot = {
		"stats": stats_data,
		"inventory": inv_data
	}

func respawn_player() -> void:
	if is_player_dead:
		return
	is_player_dead = true
	print("[GameManager] Iniciando secuencia de Respawn del jugador...")
	
	var target_scene: String = active_checkpoint_scene_path
	if target_scene.is_empty():
		target_scene = current_scene.scene_file_path if is_instance_valid(current_scene) else "res://src/overworld/levels/Lvl01.tscn"
		
	# 1. Revertir WorldStateManager al inicio del nivel donde ocurrió la muerte
	var ws: Node = get_node_or_null("/root/WorldStateManager")
	if ws and ws.has_method("restore_snapshot"):
		ws.restore_snapshot(level_entry_world_state_snapshot)
		
	# 2. Restaurar Stats e Inventario del checkpoint activo
	if active_checkpoint_player_snapshot.has("stats"):
		var stats: Node = get_node_or_null("/root/PlayerStats")
		if stats and stats.has_method("restore_snapshot"):
			stats.restore_snapshot(active_checkpoint_player_snapshot["stats"])
	else:
		var stats: Node = get_node_or_null("/root/PlayerStats")
		if stats and stats.has_method("full_heal"):
			stats.full_heal()
			
	if active_checkpoint_player_snapshot.has("inventory"):
		var inv: Node = get_node_or_null("/root/Inventory")
		if inv and inv.has_method("restore_snapshot"):
			inv.restore_snapshot(active_checkpoint_player_snapshot["inventory"])
			
	# 3. Transicionar a la escena del checkpoint en "RespawnPoint"
	await change_level(target_scene, "RespawnPoint")
	
	is_player_dead = false
	player_respawned.emit()
	print("[GameManager] Respawn completado con éxito en: ", target_scene)

func _snap_scene_cameras(node: Node) -> void:
	if node is Camera2D:
		if node.has_method("snap_to_target"):
			node.snap_to_target()
		else:
			node.reset_smoothing()
			node.force_update_scroll()
	for child in node.get_children():
		_snap_scene_cameras(child)

func register_pursuer(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return
	if not _active_pursuers.has(enemy):
		_active_pursuers.append(enemy)
	_update_alert_state()

func unregister_pursuer(enemy: Node) -> void:
	if _active_pursuers.has(enemy):
		_active_pursuers.erase(enemy)
	_update_alert_state()

func is_in_alert() -> bool:
	_cleanup_invalid_pursuers()
	return alert_state == WorldAlertState.ALERT

func clear_pursuers() -> void:
	_active_pursuers.clear()
	_update_alert_state()

func _cleanup_invalid_pursuers() -> void:
	_active_pursuers = _active_pursuers.filter(func(node: Node) -> bool: return is_instance_valid(node) and node.is_inside_tree())

func _update_alert_state() -> void:
	_cleanup_invalid_pursuers()
	var new_state: WorldAlertState = WorldAlertState.ALERT if _active_pursuers.size() > 0 else WorldAlertState.PEACE
	if new_state != alert_state:
		alert_state = new_state
		alert_state_changed.emit(alert_state)
