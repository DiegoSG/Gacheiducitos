extends Area2D
class_name FallingItemBase

signal hit_floor
signal caught(item_type: int)

enum ItemType { POINT, BOMB }

@export var item_type: ItemType = ItemType.POINT
@export var fall_speed_multiplier: float = 1.0

var base_speed: float = 200.0
var current_speed: float = 200.0
var is_active: bool = false

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func setup(p_base_speed: float, p_pos: Vector2) -> void:
	base_speed = p_base_speed
	current_speed = base_speed * fall_speed_multiplier
	global_position = p_pos
	is_active = true

func _process(delta: float) -> void:
	if not is_active:
		return
	
	global_position.y += current_speed * delta
	
	# Cleanup if it goes way out of bounds (fallback)
	if global_position.y > get_viewport_rect().size.y + 200:
		queue_free()

# Usually bounded by a generic bottom 'Floor' Area2D
func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("catcher_floor"):
		hit_floor.emit(item_type)
		is_active = false
		# Wait for end of frame to free
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("catcher_player"):
		caught.emit(item_type)
		is_active = false
		queue_free()
