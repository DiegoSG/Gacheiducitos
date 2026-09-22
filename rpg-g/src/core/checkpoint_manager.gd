extends Node

signal player_respawned

var active_checkpoint_scene_path: String = ""
var active_checkpoint_player_snapshot: Dictionary = {}
var level_entry_world_state_snapshot: Dictionary = {}
var is_player_dead: bool = false

func register_level_entry(scene_path: String, scene_node: Node) -> void:
	if not is_instance_valid(scene_node):
		return
	
	# Respaldar estado del mundo al inicio de este nivel (para revertir si muere aquí)
	var ws := WorldStateManager
	if ws:
		level_entry_world_state_snapshot = ws.create_snapshot()
		print("[CheckpointManager] WorldState snapshot registrado para el nivel: ", scene_path)
	
	# Verificar si este nivel es Checkpoint
	var is_checkpoint: bool = false
	if scene_node.has_node("CheckpointLevel") or _find_node_by_class(scene_node, "CheckpointLevel") != null:
		is_checkpoint = true
	elif active_checkpoint_scene_path.is_empty() and not scene_path.is_empty():
		is_checkpoint = true
		
	if is_checkpoint and not scene_path.is_empty():
		active_checkpoint_scene_path = scene_path
		_capture_checkpoint_player_snapshot()
		print("[CheckpointManager] Checkpoint activo actualizado a: ", active_checkpoint_scene_path)

func _find_node_by_class(root: Node, class_str: String) -> Node:
	if root.get_class() == class_str or root.is_class(class_str) or (root.get_script() and root.get_script().get_global_name() == class_str):
		return root
	for child: Node in root.get_children():
		var found: Node = _find_node_by_class(child, class_str)
		if found:
			return found
	return null

func _capture_checkpoint_player_snapshot() -> void:
	var stats := PlayerStats
	var inv := Inventory
	var stats_data: Dictionary = stats.create_snapshot() if stats else {}
	var inv_data: Dictionary = inv.create_snapshot() if inv else {}
	active_checkpoint_player_snapshot = {
		"stats": stats_data,
		"inventory": inv_data
	}

func respawn_player() -> void:
	if is_player_dead:
		return
	is_player_dead = true
	print("[CheckpointManager] Iniciando secuencia de Respawn del jugador...")
	
	var gm := GameManager
	var target_scene: String = active_checkpoint_scene_path
	if target_scene.is_empty():
		if gm and is_instance_valid(gm.current_scene):
			target_scene = gm.current_scene.scene_file_path
		else:
			target_scene = "res://src/overworld/levels/Lvl01.tscn"
		
	# 1. Revertir WorldStateManager al inicio del nivel donde ocurrió la muerte
	var ws := WorldStateManager
	if ws:
		ws.restore_snapshot(level_entry_world_state_snapshot)
		
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
			
	# 3. Transicionar a la escena del checkpoint
	if gm:
		await gm.change_level(target_scene, "RespawnPoint")
	
	is_player_dead = false
	player_respawned.emit()
	print("[CheckpointManager] Respawn completado con éxito en: ", target_scene)
