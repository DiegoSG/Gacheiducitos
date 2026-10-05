class_name SmashCursor
extends Node2D
## Cursor del Smasher controlado por input (teclado/stick) o por el mouse.
## Con `interact` golpea al bicho que esté bajo el cursor.

## Velocidad del cursor en píxeles por segundo.
@export var speed: float = 700.0
@export var radius: float = 26.0
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


func _smash_at(point: Vector2) -> void:
	var params: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	params.position = point
	params.collide_with_areas = true
	params.collide_with_bodies = false
	for hit: Dictionary in get_world_2d().direct_space_state.intersect_point(params):
		var collider: Object = hit.get("collider")
		if collider is Insect:
			(collider as Insect).smash()
			return
	AudioManager.play_sfx(&"sfx_smash_miss")


func _draw() -> void:
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, color, 3.0)
	draw_line(Vector2(-radius - 8.0, 0.0), Vector2(radius + 8.0, 0.0), color, 2.0)
	draw_line(Vector2(0.0, -radius - 8.0), Vector2(0.0, radius + 8.0), color, 2.0)
