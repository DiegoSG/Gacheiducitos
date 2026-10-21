class_name AudioCatalog
extends Resource

## List of all audio identifiers in the game (music and sound effects).
## Edited from the Inspector: assign an AudioStream to each entry.

@export var entries: Array[AudioEntry] = []

var _cache: Dictionary[StringName, AudioEntry] = {}

## Returns the entry for the identifier, or null if it is not in the catalog.
func get_entry(id: StringName) -> AudioEntry:
	if _cache.is_empty():
		_build_cache()
	return _cache.get(id, null)

func has_entry(id: StringName) -> bool:
	return get_entry(id) != null

func _build_cache() -> void:
	for entry: AudioEntry in entries:
		if entry == null or entry.id.is_empty():
			continue
		if _cache.has(entry.id):
			push_warning("[AudioCatalog] Duplicate identifier: %s" % entry.id)
			continue
		_cache[entry.id] = entry
