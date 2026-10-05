class_name MapMenu
extends CanvasLayer

## Menú de mapa del nivel actual. Pausa el juego mientras está abierto.
## Controles: move_* desplaza, map_zoom_in/out acerca/aleja, map_center centra al jugador,
## ui_cancel pide cerrar (el MapController también cierra con map_toggle).

signal close_requested

@export var pan_speed: float = 600.0
@export var zoom_step: float = 1.25
@export var max_zoom_factor: float = 4.0
@export var min_zoom_factor: float = 0.5

@onready var _canvas: MapCanvas = $Panel/MapCanvas

var _fit_zoom: float = 0.2
var _player: Node2D = null
var _paused_by_me: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var scene: Node = GameManager.current_scene
	_canvas.level_id = MapDiscoverer.level_id_of(scene)
	_canvas.pois = MapPoiRegistry.get_pois(_canvas.level_id)
	_canvas.level_bounds = _find_bounds(scene)
	if is_instance_valid(scene):
		_player = scene.get_node_or_null("Player") as Node2D
	GameManager.request_pause()
	_paused_by_me = true
	_canvas.resized.connect(_fit_view)
	_fit_view()
	_center_on_player()

func _exit_tree() -> void:
	if _paused_by_me:
		_paused_by_me = false
		GameManager.release_pause()

func _find_bounds(scene: Node) -> Vector2:
	if is_instance_valid(scene):
		for node: Node in scene.find_children("*", "WorldBoundaryManager", true, false):
			return (node as WorldBoundaryManager).get_level_bounds()
	return Vector2(3840.0, 2160.0)

func _fit_view() -> void:
	if _canvas.size.x <= 0.0 or _canvas.size.y <= 0.0:
		return
	_fit_zoom = minf(_canvas.size.x / _canvas.level_bounds.x, _canvas.size.y / _canvas.level_bounds.y)
	_canvas.zoom = clampf(_canvas.zoom, _fit_zoom * min_zoom_factor, _fit_zoom * max_zoom_factor)
	_clamp_view()

func _center_on_player() -> void:
	if is_instance_valid(_player):
		_canvas.view_center = _player.global_position
	else:
		_canvas.view_center = _canvas.level_bounds * 0.5
	_canvas.zoom = _fit_zoom
	_clamp_view()
	_refresh()

func _clamp_view() -> void:
	_canvas.view_center = _canvas.view_center.clamp(Vector2.ZERO, _canvas.level_bounds)

func _refresh() -> void:
	if is_instance_valid(_player):
		_canvas.player_pos = _player.global_position
	else:
		_canvas.player_pos = null
	_canvas.queue_redraw()

func _set_zoom(factor: float) -> void:
	AudioManager.play_ui(&"sfx_map_zoom")
	_canvas.zoom = clampf(_canvas.zoom * factor, _fit_zoom * min_zoom_factor, _fit_zoom * max_zoom_factor)
	_refresh()

func _process(delta: float) -> void:
	var dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir != Vector2.ZERO:
		_canvas.view_center += dir * pan_speed * delta / _canvas.zoom * _fit_zoom
		_clamp_view()
	_refresh()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("map_zoom_in"):
		_set_zoom(zoom_step)
	elif event.is_action_pressed("map_zoom_out"):
		_set_zoom(1.0 / zoom_step)
	elif event.is_action_pressed("map_center"):
		AudioManager.play_ui(&"sfx_map_center")
		_center_on_player()
	elif event.is_action_pressed("ui_cancel"):
		close_requested.emit()
	else:
		return
	get_viewport().set_input_as_handled()
