extends Node

# Central registry of all game items.
# Automatically loads all ItemData .tres files from ITEMS_DIRECTORY.

const ITEMS_DIRECTORY: String = "res://data/items/"

# Internal dictionary for fast lookup: {id: ItemData}
var _item_cache: Dictionary = {}

func _ready() -> void:
	_load_items_from_dir()

func _load_items_from_dir() -> void:
	_item_cache.clear()
	if not DirAccess.dir_exists_absolute(ITEMS_DIRECTORY):
		push_warning("[ItemDatabase] Items directory does not exist: %s" % ITEMS_DIRECTORY)
		return

	# ResourceLoader.list_directory resolves the .remap files of an exported game (DirAccess does not)
	var files: PackedStringArray = ResourceLoader.list_directory(ITEMS_DIRECTORY)
	for file_name: String in files:
		if file_name.ends_with(".tres"):
			var item: Resource = load(ITEMS_DIRECTORY + file_name)
			if item is ItemData:
				var item_data: ItemData = item as ItemData
				if not item_data.id.is_empty():
					_item_cache[item_data.id] = item_data

# Returns an item by its ID (null if it does not exist).
func get_item(item_id: String) -> ItemData:
	return _item_cache.get(item_id) as ItemData

## Registers an item that is not in ITEMS_DIRECTORY (test scenes). Does not overwrite an existing one.
func register_item(item: ItemData) -> void:
	if item == null or item.id.is_empty() or _item_cache.has(item.id):
		return
	if not item.resource_path.contains("/tests/"):
		push_warning("[ItemDatabase] '%s' is not in %s; it is registered for this session only" % [item.id, ITEMS_DIRECTORY])
	_item_cache[item.id] = item
