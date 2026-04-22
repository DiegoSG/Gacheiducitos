class_name LevelAction
extends ActionResource

## Loads a new level using the GameManager.
## WARNING: Loads a new scene. This should always be the LAST action in your array because the current room (and this trigger) will be destroyed.

## The .tscn path of the level you want to load.
@export_file("*.tscn") var level_scene_path: String

## The position where the player will spawn in the new level.
@export var player_spawn_position: Vector2 = Vector2.ZERO

func get_action_name() -> String:
	return "LevelAction (%s)" % level_scene_path.get_file()

func execute(trigger_node: Node) -> void:
	var tree = trigger_node.get_tree()
	var game_manager = tree.root.get_node_or_null("GameManager")
	
	if game_manager:
		# Use load_minigame as it handles scene transitions for both levels and minigames
		game_manager.load_minigame(level_scene_path, player_spawn_position)
	else:
		print("LevelAction: GameManager not found!")
		
	finished.emit()
