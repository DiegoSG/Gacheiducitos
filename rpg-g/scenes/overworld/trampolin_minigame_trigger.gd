extends Actionable

func action() -> void:
	print("Opening Trampolin Minigame...")
	var player = get_tree().get_first_node_in_group("player")
	var return_pos = Vector2.ZERO
	if player:
		return_pos = player.global_position
	
	GameManager.load_minigame("res://scenes/minigames/mg_trampolin/trampolin_config.tscn", return_pos)
