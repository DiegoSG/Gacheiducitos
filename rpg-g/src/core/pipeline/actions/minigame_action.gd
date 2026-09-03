class_name MinigameAction
extends ActionResource

## Launches a minigame with specific configuration settings.
## WARNING: Loads a new scene. This should always be the LAST action in your array because the current room (and this trigger) will be destroyed.

## Path to the minigame .tscn file.
@export_file("*.tscn") var minigame_scene_path: String

## Path and spawn to return to if the player WINS
@export_group("Win Condition")
@export_file("*.tscn") var win_level_path: String = ""
@export var win_spawn_id: String = ""

## Path and spawn to return to if the player LOSES
@export_group("Lose Condition")
@export_file("*.tscn") var lose_level_path: String = ""
@export var lose_spawn_id: String = ""

## Dictionary with configuration to pass down to the minigame.
@export var config: Dictionary = {}

func get_action_name() -> String:
	return "MinigameAction (%s)" % minigame_scene_path.get_file()

func execute(trigger_node: Node) -> void:
	var tree = trigger_node.get_tree()
	var game_manager = tree.root.get_node_or_null("GameManager")
	
	if game_manager:
		# Inyectar rutas de retorno
		var final_config = config.duplicate()
		final_config["win_level_path"] = win_level_path
		final_config["win_spawn_id"] = win_spawn_id
		final_config["lose_level_path"] = lose_level_path
		final_config["lose_spawn_id"] = lose_spawn_id
		
		# Set config globally
		game_manager.minigame_config = final_config
		
		# Load the minigame
		# We don't await because scene loading usually clears the current scene
		game_manager.load_minigame(minigame_scene_path)
	else:
		print("MinigameAction: GameManager not found!")
		
	# Since loading a minigame usually transitions to a new scene, this sequence is essentially over
	finished.emit()
