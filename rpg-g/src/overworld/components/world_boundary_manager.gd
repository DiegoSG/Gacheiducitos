@tool
extends Node2D
class_name WorldBoundaryManager

signal bounds_changed(new_bounds: Vector2)

@export_group("Dimensiones del Nivel")
## Ancho del nivel en píxeles
@export var width: float = 3840.0:
	set(val):
		width = maxf(val, 60.0)
		level_bounds.x = width
		if is_node_ready():
			queue_redraw()
			bounds_changed.emit(level_bounds)
			_update_camera_bounds()

## Alto del nivel en píxeles
@export var height: float = 2160.0:
	set(val):
		height = maxf(val, 60.0)
		level_bounds.y = height
		if is_node_ready():
			queue_redraw()
			bounds_changed.emit(level_bounds)
			_update_camera_bounds()

@export_group("Visualización en Editor")
## Color del marco de límites
@export var border_color: Color = Color(0.18, 0.75, 1.0, 0.85):
	set(val):
		border_color = val
		queue_redraw()

## Grosor de la línea del marco
@export var line_width: float = 4.0:
	set(val):
		line_width = val
		queue_redraw()

@export_group("Física")
## Grosor de los muros de colisión invisibles fuera de la pantalla
@export var margin_thickness: float = 100.0

var level_bounds: Vector2 = Vector2(3840, 2160)
var _static_body: StaticBody2D
static var debug_bounds_visible: bool = false

func _ready() -> void:
	add_to_group("world_boundary_managers")
	level_bounds = Vector2(width, height)
	queue_redraw()
	bounds_changed.emit(level_bounds)
	
	if not Engine.is_editor_hint():
		_create_boundaries()
		_update_camera_bounds()

func get_level_bounds() -> Vector2:
	return Vector2(width, height)

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			debug_bounds_visible = not debug_bounds_visible
			queue_redraw()

func _draw() -> void:
	if not Engine.is_editor_hint() and not debug_bounds_visible:
		return
		
	var bounds_rect = Rect2(Vector2.ZERO, level_bounds)
	
	# Marco exterior
	draw_rect(bounds_rect, border_color, false, line_width)
	
	# Esquinas decorativas de referencia
	var corner_len: float = minf(60.0, minf(level_bounds.x, level_bounds.y) * 0.1)
	var corner_color: Color = Color(1.0, 0.85, 0.2, 0.9)
	var c_thick: float = line_width + 2.0
	
	# Superior Izquierda
	draw_line(Vector2.ZERO, Vector2(corner_len, 0), corner_color, c_thick)
	draw_line(Vector2.ZERO, Vector2(0, corner_len), corner_color, c_thick)
	
	# Superior Derecha
	var top_right = Vector2(level_bounds.x, 0)
	draw_line(top_right, top_right + Vector2(-corner_len, 0), corner_color, c_thick)
	draw_line(top_right, top_right + Vector2(0, corner_len), corner_color, c_thick)
	
	# Inferior Izquierda
	var bl = Vector2(0, level_bounds.y)
	draw_line(bl, bl + Vector2(corner_len, 0), corner_color, c_thick)
	draw_line(bl, bl + Vector2(0, -corner_len), corner_color, c_thick)
	
	# Inferior Derecha
	var br = level_bounds
	draw_line(br, br + Vector2(-corner_len, 0), corner_color, c_thick)
	draw_line(br, br + Vector2(0, -corner_len), corner_color, c_thick)
	
	# Información de dimensiones
	if Engine.is_editor_hint():
		var tiles_x: int = int(round(level_bounds.x / 60.0))
		var tiles_y: int = int(round(level_bounds.y / 60.0))
		var info_text: String = "Límites de Nivel: %d x %d px (%d x %d tiles de 60px)" % [int(level_bounds.x), int(level_bounds.y), tiles_x, tiles_y]
		var font: Font = ThemeDB.fallback_font
		var font_size: int = 18
		draw_string(font, Vector2(16, 28), info_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, corner_color)

func _update_camera_bounds() -> void:
	var root = get_parent()
	if not root:
		return
	for child in root.find_children("*", "Camera2D", true, false):
		if child is Camera2D:
			child.limit_left = 0
			child.limit_top = 0
			child.limit_right = int(level_bounds.x)
			child.limit_bottom = int(level_bounds.y)
			if child.has_method("setup_bounds") and not Engine.is_editor_hint():
				child.setup_bounds(level_bounds)

func _create_boundaries() -> void:
	if is_instance_valid(_static_body):
		_static_body.queue_free()

	_static_body = StaticBody2D.new()
	_static_body.name = "WorldBoundaries"
	_static_body.collision_layer = 1
	_static_body.collision_mask = 0
	add_child(_static_body)

	# Borde Izquierdo
	_add_wall_shape(
		Vector2(-margin_thickness / 2.0, level_bounds.y / 2.0),
		Vector2(margin_thickness, level_bounds.y + margin_thickness * 2.0)
	)

	# Borde Derecho
	_add_wall_shape(
		Vector2(level_bounds.x + margin_thickness / 2.0, level_bounds.y / 2.0),
		Vector2(margin_thickness, level_bounds.y + margin_thickness * 2.0)
	)

	# Borde Superior
	_add_wall_shape(
		Vector2(level_bounds.x / 2.0, -margin_thickness / 2.0),
		Vector2(level_bounds.x + margin_thickness * 2.0, margin_thickness)
	)

	# Borde Inferior
	_add_wall_shape(
		Vector2(level_bounds.x / 2.0, level_bounds.y + margin_thickness / 2.0),
		Vector2(level_bounds.x + margin_thickness * 2.0, margin_thickness)
	)

func _add_wall_shape(pos: Vector2, size: Vector2) -> void:
	var col := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size
	col.shape = box
	col.position = pos
	_static_body.add_child(col)
