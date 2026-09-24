extends Node

signal player_respawned

var active_checkpoint_scene_path: String = ""
var active_checkpoint_player_snapshot: Dictionary = {}
var level_entry_world_state_snapshot: Dictionary = {}
var level_entry_narrative_snapshot: Dictionary = {}
var _is_player_dead: bool = false

@export var checkpoints_until_autosave: int = 3
var _checkpoints_passed_count: int = 0

func register_level_entry(scene_path: String, scene_node: Node) -> void:
	if not is_instance_valid(scene_node):
		return
		
	# No registrar checkpoints en minijuegos
	if scene_node.get_class() == "MinigameBase" or scene_node.is_class("MinigameBase") or (scene_node.get_script() and scene_node.get_script().get_global_name() == "MinigameBase") or scene_path.contains("/minigames/"):
		return
	
	# Respaldar estado del mundo al inicio de este nivel (para revertir si muere aquí)
	var ws := WorldStateManager
	if ws:
		level_entry_world_state_snapshot = ws.create_snapshot()
		print("[CheckpointManager] WorldState snapshot registrado para el nivel: ", scene_path)
	
	var nm := NarrativeManager
	if nm:
		level_entry_narrative_snapshot = nm.create_snapshot()
	
	# Cada nivel del overworld es un checkpoint donde reapareceremos al morir
	active_checkpoint_scene_path = scene_path
	_capture_checkpoint_player_snapshot()
	print("[CheckpointManager] Checkpoint activo actualizado a: ", active_checkpoint_scene_path)
	
	_checkpoints_passed_count += 1
	if _checkpoints_passed_count >= checkpoints_until_autosave:
		_checkpoints_passed_count = 0
		var ss = get_node_or_null("/root/SaveSystem")
		if ss and ss.has_method("save_slot"):
			ss.save_slot(ss.AUTOSAVE_SLOT_ID)

func _capture_checkpoint_player_snapshot() -> void:
	var stats := PlayerStats
	var inv := Inventory
	var stats_data: Dictionary = stats.create_snapshot() if stats else {}
	var inv_data: Dictionary = inv.create_snapshot() if inv else {}
	
	var gm := GameManager
	var player = gm.current_scene.get_node_or_null("Player") if gm and is_instance_valid(gm.current_scene) else null
	var pos = player.global_position if player else Vector2.ZERO
	
	active_checkpoint_player_snapshot = {
		"stats": stats_data,
		"inventory": inv_data,
		"position": {"x": pos.x, "y": pos.y}
	}

func respawn_player() -> void:
	if _is_player_dead:
		return
	_is_player_dead = true
	print("[CheckpointManager] Iniciando secuencia de Respawn del jugador...")
	
	var gm := GameManager
	var target_scene: String = active_checkpoint_scene_path
	if target_scene.is_empty():
		if gm and is_instance_valid(gm.current_scene):
			target_scene = gm.current_scene.scene_file_path
		else:
			target_scene = "res://src/overworld/levels/Lvl01.tscn"
		
	# 1. Revertir WorldStateManager y NarrativeManager al inicio del nivel
	var ws := WorldStateManager
	if ws:
		ws.restore_snapshot(level_entry_world_state_snapshot)
	var nm := NarrativeManager
	if nm and not level_entry_narrative_snapshot.is_empty():
		nm.restore_snapshot(level_entry_narrative_snapshot)
		
	# 2. Restaurar Stats e Inventario del checkpoint activo
	if active_checkpoint_player_snapshot.has("stats"):
		var stats := PlayerStats
		if stats:
			stats.restore_snapshot(active_checkpoint_player_snapshot["stats"])
	else:
		var stats := PlayerStats
		if stats:
			stats.full_heal()
			
	if active_checkpoint_player_snapshot.has("inventory"):
		var inv := Inventory
		if inv:
			inv.restore_snapshot(active_checkpoint_player_snapshot["inventory"])
			
	# 3. Transicionar a la escena del checkpoint en la posicion de entrada
	var exact_pos: Vector2 = Vector2.ZERO
	if active_checkpoint_player_snapshot.has("position"):
		var p_dict: Dictionary = active_checkpoint_player_snapshot["position"] as Dictionary
		exact_pos = Vector2(p_dict["x"], p_dict["y"])
		
	if gm:
		await gm.change_level(target_scene, "", exact_pos, true, true)
	
	_is_player_dead = false
	player_respawned.emit()
	print("[CheckpointManager] Respawn completado con éxito en: ", target_scene)
