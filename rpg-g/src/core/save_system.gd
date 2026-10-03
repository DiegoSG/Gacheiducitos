extends Node

const SAVE_PATH_AUTO: String = "user://save_auto.json"
const SAVE_PATH_SLOT_PATTERN: String = "user://save_slot_%d.json"
const AUTOSAVE_SLOT_ID: int = 0
const MAX_MANUAL_SLOTS: int = 4

signal game_saved(slot_id: int)
signal game_loaded(slot_id: int)
signal game_deleted(slot_id: int)

func get_slot_path(slot_id: int) -> String:
	if slot_id == AUTOSAVE_SLOT_ID:
		return SAVE_PATH_AUTO
	return SAVE_PATH_SLOT_PATTERN % slot_id

func save_slot(slot_id: int) -> void:
	if not is_instance_valid(GameManager.current_scene):
		return

	var current_scene: Node = GameManager.current_scene
	var player: Node2D = current_scene.get_node_or_null("Player") as Node2D
	var p_pos: Vector2 = player.global_position if player else Vector2.ZERO

	var data: Dictionary = {
		"version": 1,
		"save_type": "auto" if slot_id == AUTOSAVE_SLOT_ID else "manual",
		"timestamp": Time.get_unix_time_from_system(),
		"level": {
			"scene_path": current_scene.scene_file_path,
			"player_position": {"x": p_pos.x, "y": p_pos.y}
		},
		"player_stats": PlayerStats.create_snapshot(),
		"inventory": Inventory.create_snapshot(),
		"narrative": GameVariables.create_snapshot(),
		"world_state": WorldStateManager.create_snapshot(),
		"quick_slots": QuickSlots.create_snapshot()
	}

	var file_path: String = get_slot_path(slot_id)
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		game_saved.emit(slot_id)
	else:
		push_error("[SaveSystem] Error guardando archivo: ", file_path)

func load_slot(slot_id: int) -> void:
	var file_path: String = get_slot_path(slot_id)

	if not FileAccess.file_exists(file_path):
		return

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("[SaveSystem] No se pudo abrir el archivo: ", file_path)
		return
	var content: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(content)
	if not parsed is Dictionary:
		return

	var data: Dictionary = parsed as Dictionary

	if data.has("world_state"):
		WorldStateManager.restore_snapshot(data["world_state"])

	if data.has("narrative"):
		GameVariables.restore_snapshot(data["narrative"])

	if data.has("inventory"):
		Inventory.restore_snapshot(data["inventory"])

	# Retrocompatible: los saves antiguos no traen "quick_slots"
	QuickSlots.restore_snapshot(data.get("quick_slots", []) as Array)

	if data.has("player_stats"):
		PlayerStats.restore_snapshot(data["player_stats"])

	if data.has("level"):
		var level_data: Dictionary = data["level"] as Dictionary
		var path: String = level_data.get("scene_path", "")
		var pos_dict: Dictionary = level_data.get("player_position", {"x": 0, "y": 0})
		var pos: Vector2 = Vector2(pos_dict["x"], pos_dict["y"])

		get_tree().paused = false
		await GameManager.change_level(path, "", pos, true, true)

	game_loaded.emit(slot_id)

func get_slot_metadata(slot_id: int) -> Dictionary:
	var path: String = get_slot_path(slot_id)
	if not FileAccess.file_exists(path):
		return {"exists": false}
		
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {"exists": false}
		
	var content: String = file.get_as_text()
	file.close()
	
	var parsed: Variant = JSON.parse_string(content)
	if not parsed is Dictionary:
		return {"exists": false}
		
	var data: Dictionary = parsed as Dictionary
	var timestamp: float = data.get("timestamp", 0.0)
	var level_name: String = "Desconocido"
	
	if data.has("level") and data["level"] is Dictionary:
		var level_dict: Dictionary = data["level"] as Dictionary
		var path_str: String = level_dict.get("scene_path", "")
		level_name = path_str.get_file().get_basename()
		
	var hp: int = 0
	var max_hp: int = 0
	var gold: int = 0
	if data.has("player_stats") and data["player_stats"] is Dictionary:
		var stats_dict: Dictionary = data["player_stats"] as Dictionary
		hp = int(stats_dict.get("health", 0))
		max_hp = int(stats_dict.get("max_health", 0))
		gold = int(stats_dict.get("gold", 0))
			
	return {
		"exists": true,
		"timestamp": timestamp,
		"level_name": level_name,
		"health": hp,
		"max_health": max_hp,
		"gold": gold
	}

func get_all_slots_metadata() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(MAX_MANUAL_SLOTS + 1):
		result.append(get_slot_metadata(i))
	return result

func delete_slot(slot_id: int) -> void:
	var file_path: String = get_slot_path(slot_id)
	if FileAccess.file_exists(file_path):
		var err: Error = DirAccess.remove_absolute(file_path)
		if err == OK:
			game_deleted.emit(slot_id)
		else:
			push_error("[SaveSystem] Error al borrar el archivo: ", file_path)
