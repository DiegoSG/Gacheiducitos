class_name LevelAction
extends ActionResource

## Cambia de nivel usando GameManager.change_level (con fundido y colocación en el punto de llegada).
## WARNING: Loads a new scene. This should always be the LAST action in your array because the current room (and this trigger) will be destroyed.

## The .tscn path of the level you want to load.
@export_file("*.tscn") var level_scene_path: String

## arrival_id del ArrivalSpawnPoint/LevelPortal del nivel destino donde aparecerá el jugador (vacío = posición por defecto).
@export var arrival_id: String = ""

func get_action_name() -> String:
	return "LevelAction (%s)" % level_scene_path.get_file()

func execute(_trigger_node: Node) -> void:
	GameManager.change_level(level_scene_path, arrival_id)
	finished.emit()
