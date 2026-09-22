extends Node

const SAVE_PATH_MANUAL: String = "user://save_manual.json"
const SAVE_PATH_AUTO: String = "user://save_auto.json"

signal game_saved(is_autosave: bool)
signal game_loaded

func save_current_state(is_autosave: bool = false) -> void:
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
		"save_type": "auto" if is_autosave else "manual",
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

	var file_path: String = SAVE_PATH_AUTO if is_autosave else SAVE_PATH_MANUAL
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		game_saved.emit(is_autosave)
		print("[SaveSystem] Partida guardada en: ", file_path)
	else:
		push_error("[SaveSystem] Error guardando archivo.")

func load_saved_state(is_autosave: bool = false) -> void:
	var file_path: String = SAVE_PATH_AUTO if is_autosave else SAVE_PATH_MANUAL
	
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

		await gm.change_level(path, "", pos, true, true)

	game_loaded.emit()
	print("[SaveSystem] Partida cargada exitosamente.")
