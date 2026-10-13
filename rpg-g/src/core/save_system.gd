extends Node

const SAVE_PATH_AUTO: String = "user://save_auto.json"
const SAVE_PATH_SLOT_PATTERN: String = "user://save_slot_%d.json"
const AUTOSAVE_SLOT_ID: int = 0
const MAX_MANUAL_SLOTS: int = 4
## Copia de la partida anterior de cada slot; se usa si el archivo principal está dañado.
const BACKUP_SUFFIX: String = ".bak"

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
		"quick_slots": QuickSlots.create_snapshot(),
		"map_discovery": WorldStateManager.create_discovery_snapshot()
	}

	var file_path: String = get_slot_path(slot_id)
	_backup_slot_file(file_path)
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		# El autoguardado suena con sfx_save_autosave (CheckpointManager)
		if slot_id != AUTOSAVE_SLOT_ID:
			AudioManager.play_ui(&"sfx_save_done")
		game_saved.emit(slot_id)
	else:
		AudioManager.play_ui(&"sfx_save_error")
		push_error("[SaveSystem] Error guardando archivo: ", file_path)

func load_slot(slot_id: int) -> void:
	var data: Dictionary = _read_slot_data(get_slot_path(slot_id))
	if data.is_empty():
		return

	if data.has("world_state"):
		WorldStateManager.restore_snapshot(data["world_state"])

	# Retrocompatible: saves antiguos no traen "map_discovery".
	var discovery: Variant = data.get("map_discovery", {})
	WorldStateManager.restore_discovery_snapshot(discovery if discovery is Dictionary else {})

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

	AudioManager.play_ui(&"sfx_save_loaded")
	game_loaded.emit(slot_id)

func get_slot_metadata(slot_id: int) -> Dictionary:
	var data: Dictionary = _read_slot_data(get_slot_path(slot_id))
	if data.is_empty():
		return {"exists": false}

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
			if FileAccess.file_exists(file_path + BACKUP_SUFFIX):
				DirAccess.remove_absolute(file_path + BACKUP_SUFFIX)
			AudioManager.play_ui(&"sfx_save_deleted")
			game_deleted.emit(slot_id)
		else:
			push_error("[SaveSystem] Error al borrar el archivo: ", file_path)

## Copia el archivo actual del slot a su backup antes de sobrescribirlo.
func _backup_slot_file(file_path: String) -> void:
	if not FileAccess.file_exists(file_path):
		return
	var err: Error = DirAccess.copy_absolute(file_path, file_path + BACKUP_SUFFIX)
	if err != OK:
		push_warning("[SaveSystem] No se pudo crear el backup de %s (error %d)" % [file_path, err])

## Lee la partida del slot. Si el archivo principal falta o está dañado, usa el backup.
## Devuelve un diccionario vacío si ninguno se puede leer.
func _read_slot_data(file_path: String) -> Dictionary:
	var data: Dictionary = _parse_save_file(file_path)
	if data.is_empty():
		data = _parse_save_file(file_path + BACKUP_SUFFIX)
		if not data.is_empty():
			push_warning("[SaveSystem] Partida dañada o ausente, se usó el backup: ", file_path)
	return data

func _parse_save_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("[SaveSystem] No se pudo abrir el archivo: ", path)
		return {}
	var content: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(content)
	if not parsed is Dictionary:
		return {}
	return parsed as Dictionary
