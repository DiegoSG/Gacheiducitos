extends CharacterBody2D
class_name CatcherPlayer

var speed: float = 600.0

func _ready() -> void:
	add_to_group("catcher_player")

func _physics_process(delta: float) -> void:
	var input_dir = Input.get_axis("ui_left", "ui_right")
	velocity.x = input_dir * speed
	velocity.y = 0
	
	move_and_slide()
	
	var screen_size = get_viewport_rect().size
	var margin = 20.0
	global_position.x = clamp(global_position.x, margin, screen_size.x - margin)
