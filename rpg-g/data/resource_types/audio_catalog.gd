class_name AudioCatalog
extends Resource

## Lista de todos los identificadores de audio del juego (música y efectos).
## Se edita desde el Inspector: asignar un AudioStream a cada entrada.

@export var entries: Array[AudioEntry] = []

var _cache: Dictionary[StringName, AudioEntry] = {}

## Devuelve la entrada del identificador, o null si no está en el catálogo.
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
			push_warning("[AudioCatalog] Identificador duplicado: %s" % entry.id)
			continue
		_cache[entry.id] = entry
