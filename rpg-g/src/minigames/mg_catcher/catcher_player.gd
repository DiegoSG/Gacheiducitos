extends CharacterBody2D
class_name CatcherPlayer

var speed: float = 600.0

@onready var sprite: Sprite2D = $Sprite2D

const TEX_DOWN: Texture2D = preload("res://assets/sprites/player_down.png")
const TEX_SIDE: Texture2D = preload("res://assets/sprites/player_side.png")

func _ready() -> void:
	add_to_group("catcher_player")
	if sprite:
		sprite.texture = TEX_DOWN

func _physics_process(_delta: float) -> void:
	var input_dir: float = Input.get_axis("ui_left", "ui_right")
	velocity.x = input_dir * speed
	velocity.y = 0

	if sprite:
		if input_dir > 0:
			sprite.texture = TEX_SIDE
			sprite.flip_h = false
		elif input_dir < 0:
			sprite.texture = TEX_SIDE
			sprite.flip_h = true
		else:
			sprite.texture = TEX_DOWN
			sprite.flip_h = false

	move_and_slide()

	var screen_size: Vector2 = get_viewport_rect().size
	var margin: float = 20.0
	global_position.x = clamp(global_position.x, margin, screen_size.x - margin)
