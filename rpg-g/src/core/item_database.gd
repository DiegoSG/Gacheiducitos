extends Node

# A centralized registry for all items in the game
# You can add items to this list in the Inspector of the Autoload (if registered with a scene)
# or we can automatically load them from a folder.

@export var all_items: Array[ItemData] = []
@export var data_directory: String = "res://data/items/"

# Internal dictionary for fast lookup: {id: ItemData}
var _item_cache: Dictionary = {}

func _ready() -> void:
	_load_items_from_dir()
	_refresh_cache()

func _load_items_from_dir() -> void:
	if not DirAccess.dir_exists_absolute(data_directory):
		DirAccess.make_dir_recursive_absolute(data_directory)
		return

	var dir = DirAccess.open(data_directory)
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var item = load(data_directory + file_name)
			if item is ItemData:
				all_items.append(item)
		file_name = dir.get_next()

func _refresh_cache() -> void:
	_item_cache.clear()
	for item in all_items:
		if item and not item.id.is_empty():
			_item_cache[item.id] = item

# Returns an item by its ID.
func get_item(item_id: String) -> ItemData:
	if _item_cache.is_empty() and not all_items.is_empty():
		_refresh_cache()
	
	return _item_cache.get(item_id)

# Helper for debugging
func print_all_items() -> void:
	print("Item Database Cache: ", _item_cache.keys())
