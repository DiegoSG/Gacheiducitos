extends Area2D
class_name MG_RunnerEnemy

var speed: float = 350.0
var obstacle_type: int = 2
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("runner_obstacle")
	add_to_group("runner_enemy")
	
	sprite.modulate = Color(1.0, 0.2, 0.2)
	sprite.scale = Vector2(0.5, 0.5)

func _process(delta: float) -> void:
	position.x -= speed * delta
	
	if position.x < -200.0:
		queue_free()

func die() -> void:
	queue_free()
