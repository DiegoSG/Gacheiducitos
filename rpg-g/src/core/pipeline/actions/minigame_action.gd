class_name MinigameAction
extends ActionResource

## Launches a minigame with specific configuration settings.
## WARNING: Loads a new scene. This should always be the LAST action in your array because the current room (and this trigger) will be destroyed.

## Path to the minigame .tscn file.
@export_file("*.tscn") var minigame_scene_path: String

## Dictionary with configuration to pass down to the minigame.
@export var config: Dictionary = {}

func get_action_name() -> String:
	return "MinigameAction (%s)" % minigame_scene_path.get_file()

func execute(trigger_node: Node) -> void:
	var tree = trigger_node.get_tree()
	var game_manager = tree.root.get_node_or_null("GameManager")
	
	if game_manager:
		# Set config globally
		game_manager.minigame_config = config
		
		# Load the minigame
		# We don't await because scene loading usually clears the current scene
		game_manager.load_minigame(minigame_scene_path)
	else:
		print("MinigameAction: GameManager not found!")
		
	# Since loading a minigame usually transitions to a new scene, this sequence is essentially over
	finished.emit()
