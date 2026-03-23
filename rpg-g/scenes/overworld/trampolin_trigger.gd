extends Area2D

@export_file("*.tscn") var minigame_scene_path: String = "res://scenes/minigames/mg_trampolin/mg_trampolin.tscn"

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		# Guardar la escena actual y configurar el minijuego
		GameManager.previous_scene_path = get_tree().current_scene.scene_file_path
		GameManager.minigame_config = {
			"dificultad": 1.0,
			"escala": 1.5
		}
		
		# Cargar la pantalla de configuración (o el minijuego directo si prefieres)
		# Por ahora, vamos directo al minijuego
		GameManager.load_minigame(minigame_scene_path, Vector2.ZERO)
