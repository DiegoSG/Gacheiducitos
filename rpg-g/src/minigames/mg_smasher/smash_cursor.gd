class_name SmashCursor
extends Node2D
## Cursor del Smasher controlado por input (teclado/stick) o por el mouse.
## Con `interact` (o click izquierdo) golpea al bicho más cercano dentro de
## `hit_radius`, que es más grande que la mira para que el golpe perdone un poco.

## Velocidad del cursor en píxeles por segundo.
@export var speed: float = 700.0
## Radio de la mira (solo visual).
@export var radius: float = 26.0
## Radio del impacto. Debe ser mayor que `radius`.
@export var hit_radius: float = 48.0
@export var color: Color = Color(1.0, 0.9, 0.2, 0.9)

var _last_mouse_pos: Vector2 = Vector2.INF


func _ready() -> void:
	z_index = 100
	position = get_viewport_rect().size / 2.0
	_last_mouse_pos = get_viewport().get_mouse_position()


func _process(delta: float) -> void:
	var bounds: Rect2 = get_viewport_rect()
	var dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	if dir != Vector2.ZERO:
		position += dir * speed * delta
	elif mouse_pos != _last_mouse_pos:
		position = get_global_mouse_position()
	_last_mouse_pos = mouse_pos
	position = position.clamp(bounds.position, bounds.end)

	if Input.is_action_just_pressed("interact"):
		_smash_at(global_position)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		position = get_global_mouse_position()
		_smash_at(global_position)


func _smash_at(point: Vector2) -> void:
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = hit_radius
	var params: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, point)
	params.collide_with_areas = true
	params.collide_with_bodies = false
	var target: Insect = null
	var best_dist: float = INF
	for hit: Dictionary in get_world_2d().direct_space_state.intersect_shape(params):
		var insect: Insect = hit.get("collider") as Insect
		if insect == null or not insect.is_active:
			continue
		var dist: float = point.distance_squared_to(insect.global_position)
		if dist < best_dist:
			best_dist = dist
			target = insect
	if target != null:
		target.smash()
	else:
		AudioManager.play_sfx(&"sfx_smash_miss")


func _draw() -> void:
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, color, 3.0)
	draw_line(Vector2(-radius - 8.0, 0.0), Vector2(radius + 8.0, 0.0), color, 2.0)
	draw_line(Vector2(0.0, -radius - 8.0), Vector2(0.0, radius + 8.0), color, 2.0)
