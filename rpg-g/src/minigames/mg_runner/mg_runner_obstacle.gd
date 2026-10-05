extends Area2D
class_name MG_RunnerObstacle

enum ObstacleType { LOW = 1, HIGH = 2, TALL = 3 }
@export var obstacle_type: ObstacleType = ObstacleType.LOW
var speed: float = 380.0

# Dimensiones configurables en inspector
@export var low_width: float = 54.0
@export var low_height: float = 75.0

@export var high_width: float = 64.0
@export var high_height: float = 60.0
@export var high_bottom_clearance: float = 62.0 # Espacio libre para pasar agachado

@export var tall_width: float = 54.0
@export var tall_height: float = 160.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("runner_obstacle")
	_setup_visuals()

func _setup_visuals() -> void:
	var shape = RectangleShape2D.new()
	var tex = sprite.texture
	var base_w: float = float(tex.get_width()) if tex != null else 128.0
	var base_h: float = float(tex.get_height()) if tex != null else 128.0

	match obstacle_type:
		ObstacleType.LOW:
			# Obstáculo en suelo (cactus/caja baja) -> Requiere SALTO
			shape.size = Vector2(low_width, low_height)
			collision_shape.shape = shape
			collision_shape.position = Vector2(0, -low_height * 0.5)
			sprite.position = Vector2(0, -low_height * 0.5)
			sprite.scale = Vector2(low_width / base_w, low_height / base_h)
			sprite.modulate = Color(0.92, 0.45, 0.15) # Naranja / Madera

		ObstacleType.HIGH:
			# Obstáculo aéreo suspendido -> Requiere AGACHARSE
			shape.size = Vector2(high_width, high_height)
			collision_shape.shape = shape
			var center_y = -(high_bottom_clearance + (high_height * 0.5))
			collision_shape.position = Vector2(0, center_y)
			sprite.position = Vector2(0, center_y)
			sprite.scale = Vector2(high_width / base_w, high_height / base_h)
			sprite.modulate = Color(0.85, 0.25, 0.85) # Púrpura / Volador

		ObstacleType.TALL:
			# Muro total -> Requiere DISPARO con bala Z
			shape.size = Vector2(tall_width, tall_height)
			collision_shape.shape = shape
			collision_shape.position = Vector2(0, -tall_height * 0.5)
			sprite.position = Vector2(0, -tall_height * 0.5)
			sprite.scale = Vector2(tall_width / base_w, tall_height / base_h)
			sprite.modulate = Color(0.45, 0.5, 0.55) # Gris / Muro

func _process(delta: float) -> void:
	position.x -= speed * delta
	if position.x < -200.0:
		queue_free()

func hit_by_bullet() -> void:
	AudioManager.play_sfx(&"sfx_run_obstacle_destroyed")
	queue_free()
