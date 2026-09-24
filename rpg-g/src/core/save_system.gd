extends Node

const SAVE_PATH_AUTO: String = "user://save_auto.json"
const SAVE_PATH_SLOT_PATTERN: String = "user://save_slot_%d.json"
const AUTOSAVE_SLOT_ID: int = 0
const MAX_MANUAL_SLOTS: int = 4

signal game_saved(slot_id: int)
signal game_loaded(slot_id: int)

func get_slot_path(slot_id: int) -> String:
	if slot_id == AUTOSAVE_SLOT_ID:
		return SAVE_PATH_AUTO
	return SAVE_PATH_SLOT_PATTERN % slot_id

func save_slot(slot_id: int) -> void:
	var gm := GameManager
	var ws := WorldStateManager
	var ps := PlayerStats
	var inv := Inventory
	var nm := NarrativeManager

	if not gm or not is_instance_valid(gm.current_scene):
		return

	var player: Node2D = gm.current_scene.get_node_or_null("Player") as Node2D
	var p_pos: Vector2 = player.global_position if player else Vector2.ZERO

	var data: Dictionary = {
		"version": 1,
		"save_type": "auto" if slot_id == AUTOSAVE_SLOT_ID else "manual",
		"timestamp": Time.get_unix_time_from_system(),
		"level": {
			"scene_path": gm.current_scene.scene_file_path,
			"player_position": {"x": p_pos.x, "y": p_pos.y}
		},
		"player_stats": ps.create_snapshot() if ps else {},
		"inventory": inv.create_snapshot() if inv else {},
		"narrative": nm.create_snapshot() if nm else {},
		"world_state": ws.create_snapshot() if ws else {}
	}

	var file_path: String = get_slot_path(slot_id)
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		game_saved.emit(slot_id)
		print("[SaveSystem] Partida guardada en: ", file_path)
	else:
		push_error("[SaveSystem] Error guardando archivo: ", file_path)

func load_slot(slot_id: int) -> void:
	var file_path: String = get_slot_path(slot_id)
	
	if not FileAccess.file_exists(file_path):
		print("[SaveSystem] No save file found at: ", file_path)
		return

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	var content: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(content)
	if not parsed is Dictionary:
		return

	var data: Dictionary = parsed as Dictionary

	var ws := WorldStateManager
	if ws and data.has("world_state"):
		ws.restore_snapshot(data["world_state"])

	var nm := NarrativeManager
	if nm and data.has("narrative"):
		nm.restore_snapshot(data["narrative"])

	var inv := Inventory
	if inv and data.has("inventory"):
		inv.restore_snapshot(data["inventory"])

	var ps := PlayerStats
	if ps and data.has("player_stats"):
		ps.restore_snapshot(data["player_stats"])

	var gm := GameManager
	if gm and data.has("level"):
		var level_data: Dictionary = data["level"] as Dictionary
		var path: String = level_data.get("scene_path", "")
		var pos_dict: Dictionary = level_data.get("player_position", {"x": 0, "y": 0})
		var pos: Vector2 = Vector2(pos_dict["x"], pos_dict["y"])

		get_tree().paused = false
		await gm.change_level(path, "", pos, true, true)

	game_loaded.emit(slot_id)
	print("[SaveSystem] Partida cargada exitosamente desde slot: ", slot_id)

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
	if data.has("player_stats") and data["player_stats"] is Dictionary:
		var stats_dict: Dictionary = data["player_stats"] as Dictionary
		hp = stats_dict.get("health", 0)
		max_hp = stats_dict.get("max_health", 0)
		
	var gold: int = 0
	if data.has("inventory") and data["inventory"] is Dictionary:
		var inv_dict: Dictionary = data["inventory"] as Dictionary
		if inv_dict.has("items") and inv_dict["items"] is Dictionary:
			var items_dict: Dictionary = inv_dict["items"] as Dictionary
			gold = items_dict.get("gold_coins", 0)
			
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

# --- Compatibilidad hacia atrás opcional (o para scripts externos que no actualizamos) ---
func save_current_state(is_autosave: bool = false) -> void:
	save_slot(AUTOSAVE_SLOT_ID if is_autosave else 1)

func load_saved_state(is_autosave: bool = false) -> void:
	load_slot(AUTOSAVE_SLOT_ID if is_autosave else 1)
