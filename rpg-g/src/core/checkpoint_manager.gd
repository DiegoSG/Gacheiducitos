extends Node

signal player_respawned

var active_checkpoint_scene_path: String = ""
var active_checkpoint_spawn_id: String = ""
var active_checkpoint_player_snapshot: Dictionary = {}
var level_entry_world_state_snapshot: Dictionary = {}
var level_entry_narrative_snapshot: Dictionary = {}
var _is_player_dead: bool = false

func register_level_entry(scene_path: String, scene_node: Node, is_organic: bool = true) -> void:
	if not is_instance_valid(scene_node):
		return
		
	# No registrar checkpoints en minijuegos
	if scene_node is MinigameBase:
		return
		
	var is_same_scene: bool = (scene_path == active_checkpoint_scene_path)
	
	# Respaldar estado del mundo al inicio de este nivel (para revertir si muere aquí)
	level_entry_world_state_snapshot = WorldStateManager.create_snapshot()
	level_entry_narrative_snapshot = GameVariables.create_snapshot()
	
	# Buscar configuración de excepción en la escena
	var exception_config: LevelExceptionConfig = null
	# find_children ya incluye a los hijos directos
	for child: Node in scene_node.find_children("*", "", true, false):
		if child is LevelExceptionConfig:
			exception_config = child as LevelExceptionConfig
			break

	# Actualizar ruta de respawn y spawn_id según si hay excepción o nivel estándar
	if exception_config:
		active_checkpoint_scene_path = exception_config.respawn_level_path
		active_checkpoint_spawn_id = exception_config.respawn_spawn_id
	else:
		active_checkpoint_scene_path = scene_path
		active_checkpoint_spawn_id = ""

	_capture_checkpoint_player_snapshot()
	if is_organic:
		AudioManager.play_ui(&"sfx_checkpoint")
	
	# Si no hay excepción (o disable_autosave es false) y es transición orgánica (not is_same_scene), ejecuta autoguardado
	var should_autosave: bool = is_organic and not is_same_scene
	if exception_config and exception_config.disable_autosave:
		should_autosave = false
		
	if should_autosave:
		AudioManager.play_ui(&"sfx_save_autosave")
		SaveSystem.save_slot(SaveSystem.AUTOSAVE_SLOT_ID)

func _capture_checkpoint_player_snapshot() -> void:
	var player: Node2D = null
	if is_instance_valid(GameManager.current_scene):
		player = GameManager.current_scene.get_node_or_null("Player") as Node2D
	var pos: Vector2 = player.global_position if player else Vector2.ZERO
	
	active_checkpoint_player_snapshot = {
		"stats": PlayerStats.create_snapshot(),
		"inventory": Inventory.create_snapshot(),
		"position": {"x": pos.x, "y": pos.y}
	}

func respawn_player() -> void:
	if _is_player_dead:
		return
	_is_player_dead = true
	
	var target_scene: String = active_checkpoint_scene_path
	if target_scene.is_empty():
		if is_instance_valid(GameManager.current_scene):
			target_scene = GameManager.current_scene.scene_file_path
		else:
			target_scene = GameManager.DEFAULT_LEVEL_PATH
		
	# 1. Revertir WorldStateManager y GameVariables al inicio del nivel
	WorldStateManager.restore_snapshot(level_entry_world_state_snapshot)
	if not level_entry_narrative_snapshot.is_empty():
		GameVariables.restore_snapshot(level_entry_narrative_snapshot)
		
	# 2. Restaurar Stats e Inventario del checkpoint activo
	if active_checkpoint_player_snapshot.has("stats"):
		PlayerStats.restore_snapshot(active_checkpoint_player_snapshot["stats"])
	else:
		PlayerStats.full_heal()
			
	if active_checkpoint_player_snapshot.has("inventory"):
		Inventory.restore_snapshot(active_checkpoint_player_snapshot["inventory"])
			
	# 3. Transicionar a la escena del checkpoint en la posicion de entrada
	var exact_pos: Vector2 = Vector2.ZERO
	if active_checkpoint_player_snapshot.has("position"):
		var p_dict: Dictionary = active_checkpoint_player_snapshot["position"] as Dictionary
		exact_pos = Vector2(p_dict["x"], p_dict["y"])
		
	await GameManager.change_level(target_scene, active_checkpoint_spawn_id, exact_pos, true, true)
	
	_is_player_dead = false
	player_respawned.emit()
