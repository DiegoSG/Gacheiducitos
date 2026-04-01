extends Area2D
class_name MG_RunnerObstacle

@export var obstacle_type: int = 1 # 1 = 1 Nivel (Salto), 2 = 2 Niveles (Muro)
var speed: float = 300.0

@onready var sprite = $Sprite2D

func _ready():
	add_to_group("runner_obstacle")
	
	# Ajustar visual según tipo para vista top-down
	if obstacle_type == 1:
		sprite.modulate = Color(0.8, 0.4, 0.1) # Marrón (Caja pequeña)
		sprite.scale = Vector2(0.5, 0.5)
	elif obstacle_type == 2:
		sprite.modulate = Color(0.4, 0.4, 0.5) # Gris (Caja alta/Muro)
		# Más larga en Y para simular que es más alta vista desde arriba
		sprite.scale = Vector2(0.6, 0.9)

func _process(delta: float):
	position.y += speed * delta
	
	if global_position.y > 1000:
		queue_free()
