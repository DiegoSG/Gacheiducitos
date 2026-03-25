class_name MinigameTrigger
extends Actionable

## Scene of the minigame to load
@export var minigame_scene: PackedScene

## Custom configuration for the minigame
@export var minigame_config: Dictionary = {
	"initial_speed": 100.0,
	"final_speed": 300.0,
	"num_holes": 4,
	"game_mode": "TIME", # "TIME" or "COUNT"
	"target_value": 30.0, # seconds or kill count
	"escape_limit": 5
}

func action() -> void:
	if not minigame_scene:
		push_warning("MinigameTrigger: No minigame scene assigned to " + name)
		return
	
	print("MinigameTrigger: Starting minigame " + minigame_scene.resource_path)
	
	# Pass config to GameManager
	GameManager.minigame_config = minigame_config
	
	# Load the minigame scene
	var path = minigame_scene.resource_path
	
	# Get player return position
	var player = get_tree().get_first_node_in_group("player")
	var return_pos = Vector2.ZERO
	if player:
		return_pos = player.global_position
	
	GameManager.load_minigame(path, return_pos)
