extends Area2D

signal smashed
signal escaped

var speed: float = 100.0
var curve: Curve2D
var path_offset: float = 0.0
var path_length: float = 0.0
var is_active: bool = false

# Sinusoidal movement parameters
var wave_amplitude: float = 0.0
var wave_frequency: float = 0.0
var time_passed: float = 0.0

func _ready() -> void:
	# Enable input picking for clicking
	input_pickable = true

func setup(p_start: Vector2, p_end: Vector2, p_speed: float) -> void:
	global_position = p_start
	speed = p_speed
	
	curve = Curve2D.new()
	var screen_center = get_viewport_rect().size / 2.0
	var offset = Vector2(randf_range(-250, 250), randf_range(-250, 250))
	var target_center = screen_center + offset
	
	var vec_out = (target_center - p_start) * 0.8
	var vec_in = (target_center - p_end) * 0.8
	
	curve.add_point(p_start, Vector2.ZERO, vec_out)
	curve.add_point(p_end, vec_in, Vector2.ZERO)
	
	path_length = curve.get_baked_length()
	path_offset = 0.0
	is_active = true
	
	# Initial rotation
	var t = curve.sample_baked_with_rotation(0.0)
	rotation = t.get_rotation()
	
	# Randomize sinusoidal wave parameters
	wave_amplitude = randf_range(20.0, 100.0)
	var wave_wavelength = randf_range(200.0, 600.0)
	wave_frequency = (2.0 * PI) / wave_wavelength
	time_passed = 0.0

func _process(delta: float) -> void:
	if not is_active:
		return
		
	path_offset += speed * delta
	
	if path_offset >= path_length:
		escaped.emit()
		is_active = false
		queue_free()
		return
		
	var t = curve.sample_baked_with_rotation(path_offset)
	var base_pos = t.get_origin()
	var base_rot = t.get_rotation()
	
	# Calculate sinusoidal offset perpendicular to movement
	var sine_val = sin(path_offset * wave_frequency)
	var offset_vector = Vector2.UP.rotated(base_rot) * sine_val * wave_amplitude
	
	global_position = base_pos + offset_vector
	
	# Slightly adjust rotation based on the wave derivative (optional but looks better)
	# For simplicity, we'll keep the base rotation or slightly offset it
	rotation = base_rot + (cos(path_offset * wave_frequency) * wave_amplitude * wave_frequency * 0.5)

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Insect smashed correctly!")
		smashed.emit()
		is_active = false
		# Add visual feedback here (e.g. particle effect)
		queue_free()
