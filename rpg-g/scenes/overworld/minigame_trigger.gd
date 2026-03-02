extends Actionable

@export var minigame_scene_path: String = "res://scenes/minigames/minigame_test.tscn"

func action() -> void:
	print("Opening Minigame Debug Config...")
	var player = get_tree().get_first_node_in_group("player")
	var return_pos = Vector2.ZERO
	if player:
		return_pos = player.global_position
	
	# Cargar pantalla de configuración de debug en lugar del minijuego directamente
	GameManager.load_minigame("res://scenes/minigames/mg_excavation/debug_config.tscn", return_pos)
