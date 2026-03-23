extends Actionable

func action() -> void:
	print("Opening Runner Minigame...")
	var player = get_tree().get_first_node_in_group("player")
	var return_pos = Vector2.ZERO
	if player:
		return_pos = player.global_position
	
	GameManager.load_minigame("res://scenes/minigames/mg_runner/mg_runner_level.tscn", return_pos)
