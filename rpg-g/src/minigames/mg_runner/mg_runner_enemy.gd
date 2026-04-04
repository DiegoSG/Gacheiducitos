extends Area2D
class_name MG_RunnerEnemy

var speed: float = 300.0
var obstacle_type: int = 2 # Behaves like a muro (No saltable)
@onready var sprite = $Sprite2D

func _ready():
	add_to_group("runner_obstacle")
	add_to_group("runner_enemy")
	
	sprite.modulate = Color(1, 0, 0) # Rojo
	sprite.scale = Vector2(0.6, 0.6)

func _process(delta: float):
	position.y += speed * delta
	
	if global_position.y > 1000:
		queue_free()

func die():
	queue_free()
