extends Node

# Singleton to manage game state and scene transitions

signal level_changed(target_level_path: String, spawn_id: String)
signal game_event(event_name: String, event_data: Variant)

func trigger_event(event_name: String, event_data: Variant = null) -> void:
	print("[GameManager] trigger_event: '%s'" % event_name)
	game_event.emit(event_name, event_data)

const FADER_SCENE: PackedScene = preload("res://src/ui/screen_fader.tscn")

var current_scene: Node = null
var previous_scene_path: String = ""
var player_return_position: Vector2 = Vector2.ZERO

# Configuración de minijuego (para debug y persistencia)
var minigame_config: Dictionary = {}
var current_level_seed: int = -1

var _minigame_win_path: String = ""
var _minigame_win_spawn_id: String = ""
var _minigame_lose_path: String = ""
var _minigame_lose_spawn_id: String = ""
var _is_changing_level: bool = false


func _ready() -> void:
	var root: Window = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)
	if is_instance_valid(current_scene):
		CheckpointManager.register_level_entry(current_scene.scene_file_path, current_scene)

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
		await get_tree().process_frame
	
	AlertSystem.clear_pursuers()
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
		var inventory := Inventory
		if not inventory and get_tree() and get_tree().root:
			inventory = Inventory
			
		if inventory:
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
		var item_db := ItemDatabase
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

func change_level(target_level_path: String, spawn_id: String = "", exact_pos: Vector2 = Vector2.ZERO, use_exact: bool = false, is_save_load: bool = false) -> void:
	if _is_changing_level:
		print("GameManager: Scene transition already in progress. Ignoring request for: ", target_level_path)
		return
	if target_level_path.is_empty():
		return

	_is_changing_level = true
	
	if not is_save_load:
		var wsm := WorldStateManager
		if wsm:
			wsm.clear_ephemeral_states()
		
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
		await get_tree().process_frame
		
	AlertSystem.clear_pursuers()
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
	CheckpointManager.register_level_entry(target_level_path, current_scene)
	level_changed.emit(target_level_path, spawn_id)

func _snap_scene_cameras(node: Node) -> void:
	if node is Camera2D:
		if node.has_method("snap_to_target"):
			node.snap_to_target()
		else:
			node.reset_smoothing()
			node.force_update_scroll()
	for child in node.get_children():
		_snap_scene_cameras(child)
