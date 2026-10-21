class_name LevelAction
extends ActionResource

## Changes level using GameManager.change_level (with a fade and placement at the arrival point).
## WARNING: Loads a new scene. This should always be the LAST action in your array because the current room (and this trigger) will be destroyed.

## The .tscn path of the level you want to load.
@export_file("*.tscn") var level_scene_path: String

## arrival_id of the ArrivalSpawnPoint/LevelPortal in the destination level where the player will appear (empty = default position).
@export var arrival_id: String = ""

func get_action_name() -> String:
	return "LevelAction (%s)" % level_scene_path.get_file()

func execute(_trigger_node: Node) -> void:
	GameManager.change_level(level_scene_path, arrival_id)
	finished.emit()
