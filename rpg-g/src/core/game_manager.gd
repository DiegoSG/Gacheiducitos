extends Node

# Singleton to manage game state and scene transitions

signal level_changed(target_level_path: String, spawn_id: String)
signal game_event(event_name: String, event_data: Variant)

const FADER_SCENE: PackedScene = preload("res://src/ui/screen_fader.tscn")
const DEFAULT_LEVEL_PATH: String = "res://src/overworld/levels/level_01.tscn"

var current_scene: Node = null
var previous_scene_path: String = ""

# Configuración de minijuego (para debug y persistencia)
var minigame_config: Dictionary = {}
var current_level_seed: int = -1

var _minigame_win_path: String = ""
var _minigame_win_spawn_id: String = ""
var _minigame_lose_path: String = ""
var _minigame_lose_spawn_id: String = ""
var _is_changing_level: bool = false

# Pausa compartida: cada sistema que necesita congelar el juego (inventario, diálogos...)
# pide una pausa y la libera; el juego solo se reanuda cuando nadie la necesita.
var _pause_requests: int = 0
var _dialogue_pause_active: bool = false


func _ready() -> void:
	# Los diálogos pausan el mundo (enemigos, timers, veneno...); el gestor de diálogos
	# debe seguir procesando mientras tanto.
	DialogueManager.process_mode = Node.PROCESS_MODE_ALWAYS
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

	var root: Window = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)
	if is_instance_valid(current_scene):
		# Permite ejecutar un minijuego suelto (F6) y que igualmente entregue recompensas
		_connect_minigame_finished(current_scene)
		CheckpointManager.register_level_entry(current_scene.scene_file_path, current_scene, false)

## Congela el juego. Cada llamada debe tener su release_pause() correspondiente.
func request_pause() -> void:
	_pause_requests += 1
	_set_paused(true)

## Libera una petición de pausa; el juego se reanuda cuando no queda ninguna.
func release_pause() -> void:
	_pause_requests = maxi(0, _pause_requests - 1)
	if _pause_requests == 0:
		_set_paused(false)

## Anula todas las pausas pendientes (al cambiar de escena, las UI que las pidieron desaparecen).
func _reset_pause() -> void:
	_pause_requests = 0
	_dialogue_pause_active = false
	_set_paused(false)

func _set_paused(paused: bool) -> void:
	if get_tree().paused == paused:
		return
	get_tree().paused = paused
	AudioManager.play_ui(&"sfx_game_paused" if paused else &"sfx_game_resumed")

func _on_dialogue_started(_resource: DialogueResource) -> void:
	if not _dialogue_pause_active:
		_dialogue_pause_active = true
		request_pause()

func _on_dialogue_ended(_resource: DialogueResource) -> void:
	AudioManager.play_ui(&"sfx_dialogue_close")
	if _dialogue_pause_active:
		_dialogue_pause_active = false
		release_pause()

func trigger_event(event_name: String, event_data: Variant = null) -> void:
	game_event.emit(event_name, event_data)

## Carga un minijuego con transición (fundido). Guarda la escena previa y las rutas de retorno
## definidas en minigame_config.
func load_minigame(minigame_path: String) -> void:
	if minigame_path.is_empty():
		push_error("GameManager: Cannot load empty minigame path.")
		return

	# Solo guardar la escena previa si NO es ya parte de una partida de minijuego
	# (Para que las escenas de prueba o el Overworld se preserven correctamente)
	if is_instance_valid(current_scene) and not (current_scene is MinigameBase):
		previous_scene_path = current_scene.scene_file_path

	# Extraer rutas de retorno de la config si existen, o usar la escena previa
	_minigame_win_path = minigame_config.get("win_level_path", previous_scene_path)
	_minigame_win_spawn_id = minigame_config.get("win_spawn_id", "")
	_minigame_lose_path = minigame_config.get("lose_level_path", previous_scene_path)
	_minigame_lose_spawn_id = minigame_config.get("lose_spawn_id", "")

	AudioManager.play_ui(&"sfx_minigame_enter")
	change_level(minigame_path)

func complete_minigame(success: bool, results: Dictionary = {}) -> void:
	# Entregar recompensas (el oro se enruta solo a PlayerStats desde Inventory.add_item)
	var pending_items: Dictionary = {}
	if results.has("items"):
		pending_items = results["items"] as Dictionary
		for item_id: String in pending_items:
			Inventory.add_item(item_id, int(pending_items[item_id]))
			
	# Determinar a dónde ir y qué spawn usar
	var target_scene: String = _minigame_win_path if success else _minigame_lose_path
	var target_spawn_id: String = _minigame_win_spawn_id if success else _minigame_lose_spawn_id
	
	# Fallback si por alguna razón están vacíos
	if target_scene.is_empty():
		target_scene = previous_scene_path if not previous_scene_path.is_empty() else DEFAULT_LEVEL_PATH
		
	AudioManager.play_ui(&"sfx_minigame_return")
	# Usar el sistema de transiciones con fader
	await change_level(target_scene, target_spawn_id)
	
	# Si obtuvimos items del minijuego, mostrar su llegada
	if not pending_items.is_empty():
		AudioManager.play_ui(&"sfx_minigame_rewards")
	for item_id: String in pending_items:
		var data: ItemData = ItemDatabase.get_item(item_id)
		if data:
			LootFeedbackManager.trigger_toast(data, int(pending_items[item_id]))

func return_to_overworld() -> void:
	var target_scene: String = previous_scene_path if not previous_scene_path.is_empty() else DEFAULT_LEVEL_PATH
	change_level(target_scene)

# Conecta game_finished de un MinigameBase a complete_minigame (única fuente de esta conexión)
func _connect_minigame_finished(scene: Node) -> void:
	if scene is MinigameBase:
		var minigame: MinigameBase = scene as MinigameBase
		if not minigame.game_finished.is_connected(complete_minigame):
			minigame.game_finished.connect(complete_minigame)

func change_level(target_level_path: String, spawn_id: String = "", exact_pos: Vector2 = Vector2.ZERO, use_exact: bool = false, is_save_load: bool = false) -> void:
	if _is_changing_level:
		return
	if target_level_path.is_empty():
		return

	_is_changing_level = true
	AudioManager.play_ui(&"sfx_level_change")
	_reset_pause()
	
	if not is_save_load:
		WorldStateManager.clear_ephemeral_states()
		
	var fader: ScreenFader = FADER_SCENE.instantiate()
	get_tree().root.add_child(fader)
	
	# Desactivar movimiento del jugador si existe
	if is_instance_valid(current_scene) and current_scene.has_node("Player"):
		current_scene.get_node("Player").set_physics_process(false)
		
	await fader.fade_out(0.4)

	var next_scene_resource: PackedScene = ResourceLoader.load(target_level_path) as PackedScene
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
	_connect_minigame_finished(current_scene)
	
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
				var spawn_node: Node2D = current_scene.get_node("SpawnPoints/" + spawn_id) as Node2D
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
	CheckpointManager.register_level_entry(target_level_path, current_scene, not is_save_load)
	AudioManager.play_ui(&"sfx_level_loaded")
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
