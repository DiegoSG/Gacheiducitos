class_name MapPoiRegistry
extends RefCounted

## Static registry of points of interest (PLACEHOLDER). Not persisted: quests
## must re-register them on load. Always shown, even if the area is not discovered.

static var _pois: Dictionary = {}

static func register_poi(poi_id: StringName, level_id: StringName, world_pos: Vector2, label: String) -> void:
	_pois[poi_id] = {"level_id": level_id, "world_pos": world_pos, "label": label}

static func remove_poi(poi_id: StringName) -> void:
	_pois.erase(poi_id)

## Returns [{poi_id, world_pos, label}] for the given level.
static func get_pois(level_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for poi_id: StringName in _pois.keys():
		var poi: Dictionary = _pois[poi_id]
		if poi["level_id"] == level_id:
			result.append({"poi_id": poi_id, "world_pos": poi["world_pos"], "label": poi["label"]})
	return result

static func clear() -> void:
	_pois.clear()
