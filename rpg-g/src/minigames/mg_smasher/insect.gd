extends Area2D

signal smashed
signal escaped

var speed: float = 100.0
var start_pos: Vector2
var end_pos: Vector2
var direction: Vector2
var is_active: bool = false

func _ready() -> void:
	# Enable input picking for clicking
	input_pickable = true
	# No need to connect input_event if we override _input_event
	# But staying consistent with implementation_plan.md's description
	input_event.connect(_on_input_event)

func setup(p_start: Vector2, p_end: Vector2, p_speed: float) -> void:
	global_position = p_start
	start_pos = p_start
	end_pos = p_end
	speed = p_speed
	direction = (end_pos - start_pos).normalized()
	is_active = true
	
	# Look at destination
	rotation = direction.angle()

func _process(delta: float) -> void:
	if not is_active:
		return
		
	global_position += direction * speed * delta
	
	# Check if reached destination
	if global_position.distance_to(start_pos) >= start_pos.distance_to(end_pos):
		escaped.emit()
		is_active = false
		queue_free()

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		smashed.emit()
		is_active = false
		# Add visual feedback here (e.g. particle effect)
		queue_free()
