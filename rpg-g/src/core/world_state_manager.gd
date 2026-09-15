extends Node

const SAVE_PATH: String = "user://world_state.json"

var _states: Dictionary = {}

signal state_saved(persistence_id: String)
signal state_loaded(persistence_id: String)

func save_state(persistence_id: String, data: Dictionary) -> void:
	if persistence_id.is_empty():
		return
	_states[persistence_id] = data.duplicate()
	state_saved.emit(persistence_id)

func load_state(persistence_id: String) -> Dictionary:
	if persistence_id.is_empty() or not _states.has(persistence_id):
		return {}
	state_loaded.emit(persistence_id)
	return _states[persistence_id].duplicate()

func has_state(persistence_id: String) -> bool:
	return not persistence_id.is_empty() and _states.has(persistence_id)

func clear_state(persistence_id: String) -> void:
	_states.erase(persistence_id)

func clear_all() -> void:
	_states.clear()

func save_to_disk() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("[WorldStateManager] No se pudo escribir en disco.")
		return
	file.store_string(JSON.stringify(_states, "\t"))
	file.close()

func load_from_disk() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_states = parsed as Dictionary
