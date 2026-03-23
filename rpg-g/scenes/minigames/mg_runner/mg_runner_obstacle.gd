extends Area2D
class_name MG_RunnerObstacle

@export var obstacle_type: int = 1 # 1 = Low (Jump over), 2 = High (Duck under), 3 = Wall (Change lane)
var speed: float = 300.0

@onready var sprite = $Sprite2D

func _ready():
	add_to_group("runner_obstacle")
	
	# Ajustar visual según tipo
	if obstacle_type == 1:
		sprite.modulate = Color(1, 0.5, 0) # Naranja (Bajo, salta)
		sprite.scale.y = 0.5
		position.y += 16 # Ajustar base
	elif obstacle_type == 2:
		sprite.modulate = Color(0, 0.5, 1) # Azul (Alto, agáchate)
		sprite.scale.y = 0.5
		position.y -= 16 # Elevar
	elif obstacle_type == 3:
		sprite.modulate = Color(1, 0, 0) # Rojo (Muro, cambia carril)
		sprite.scale.y = 1.0

func _process(delta: float):
	position.y += speed * delta
	
	# Destruir si sale de la pantalla
	if global_position.y > 1000:
		queue_free()
