extends Node

## Emitida cuando se descubre al menos una celda nueva del mapa.
signal discovered_changed(level_id: StringName)

## Tamaño en unidades de mundo de cada celda del mapa (nivel 3840x2160 -> grilla 16x16).
var map_cell_size: Vector2 = Vector2(240.0, 135.0)

var _states: Dictionary = {}
# Descubrimiento del mapa: level_id (String) -> { Vector2i: true }.
# Vive fuera de _states a propósito: el respawn NO lo revierte.
var _discovered: Dictionary = {}

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

# --- Descubrimiento del mapa ---

func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / map_cell_size.x), floori(world_pos.y / map_cell_size.y))

## Marca como descubiertas las celdas que toca el círculo (world_pos, radius).
func discover_at(level_id: StringName, world_pos: Vector2, radius: float = 0.0) -> void:
	if level_id == &"":
		return
	var key: String = String(level_id)
	var cells: Dictionary = _discovered.get(key, {})
	var changed: bool = false
	var min_c: Vector2i = world_to_cell(world_pos - Vector2(radius, radius))
	var max_c: Vector2i = world_to_cell(world_pos + Vector2(radius, radius))
	for cx: int in range(min_c.x, max_c.x + 1):
		for cy: int in range(min_c.y, max_c.y + 1):
			var rect: Rect2 = Rect2(Vector2(cx, cy) * map_cell_size, map_cell_size)
			var nearest: Vector2 = Vector2(
				clampf(world_pos.x, rect.position.x, rect.end.x),
				clampf(world_pos.y, rect.position.y, rect.end.y))
			if nearest.distance_to(world_pos) <= radius and not cells.has(Vector2i(cx, cy)):
				cells[Vector2i(cx, cy)] = true
				changed = true
	if changed:
		_discovered[key] = cells
		discovered_changed.emit(level_id)

func is_discovered(level_id: StringName, cell: Vector2i) -> bool:
	var cells: Dictionary = _discovered.get(String(level_id), {})
	return cells.has(cell)

func get_discovered_cells(level_id: StringName) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for c: Vector2i in _discovered.get(String(level_id), {}).keys():
		result.append(c)
	return result

func clear_discovery() -> void:
	_discovered.clear()

## Snapshot propio (formato JSON-safe: { level_id: ["x,y", ...] }). Se guarda en el slot, no en world_state.
func create_discovery_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for level_key: String in _discovered.keys():
		var list: Array = []
		for c: Vector2i in _discovered[level_key].keys():
			list.append("%d,%d" % [c.x, c.y])
		out[level_key] = list
	return out

func restore_discovery_snapshot(snapshot: Dictionary) -> void:
	_discovered.clear()
	for level_key: Variant in snapshot.keys():
		var cells: Dictionary = {}
		var list: Variant = snapshot[level_key]
		if list is Array:
			for entry: Variant in list:
				var parts: PackedStringArray = str(entry).split(",")
				if parts.size() == 2:
					cells[Vector2i(int(parts[0]), int(parts[1]))] = true
		_discovered[str(level_key)] = cells
	for level_key: String in _discovered.keys():
		discovered_changed.emit(StringName(level_key))
