extends Node

var _states: Dictionary = {}

func save_state(persistence_id: String, data: Dictionary) -> void:
	if persistence_id.is_empty():
		return
	_states[persistence_id] = data.duplicate()

func load_state(persistence_id: String) -> Dictionary:
	if persistence_id.is_empty() or not _states.has(persistence_id):
		return {}
	return _states[persistence_id].duplicate()

func has_state(persistence_id: String) -> bool:
	return not persistence_id.is_empty() and _states.has(persistence_id)

func clear_state(persistence_id: String) -> void:
	_states.erase(persistence_id)

func clear_ephemeral_states() -> void:
	var keys_to_remove: Array[String] = []
	for key in _states.keys():
		var k: String = str(key)
		if k.ends_with("_ephemeral") or k.begins_with("ephemeral_"):
			keys_to_remove.append(key)
	for key in keys_to_remove:
		_states.erase(key)

func clear_all() -> void:
	_states.clear()

func create_snapshot() -> Dictionary:
	return _states.duplicate(true)

func restore_snapshot(snapshot: Dictionary) -> void:
	_states = snapshot.duplicate(true)
