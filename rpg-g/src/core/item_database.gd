extends Node

# Registro centralizado de todos los ítems del juego.
# Carga automáticamente todos los .tres de ItemData desde ITEMS_DIRECTORY.

const ITEMS_DIRECTORY: String = "res://data/items/"

# Diccionario interno para búsqueda rápida: {id: ItemData}
var _item_cache: Dictionary = {}

func _ready() -> void:
	_load_items_from_dir()

func _load_items_from_dir() -> void:
	_item_cache.clear()
	if not DirAccess.dir_exists_absolute(ITEMS_DIRECTORY):
		push_warning("[ItemDatabase] No existe el directorio de ítems: %s" % ITEMS_DIRECTORY)
		return

	# ResourceLoader.list_directory resuelve los .remap de un juego exportado (DirAccess no)
	var files: PackedStringArray = ResourceLoader.list_directory(ITEMS_DIRECTORY)
	for file_name: String in files:
		if file_name.ends_with(".tres"):
			var item: Resource = load(ITEMS_DIRECTORY + file_name)
			if item is ItemData:
				var item_data: ItemData = item as ItemData
				if not item_data.id.is_empty():
					_item_cache[item_data.id] = item_data

# Devuelve un ítem por su ID (null si no existe).
func get_item(item_id: String) -> ItemData:
	return _item_cache.get(item_id) as ItemData
