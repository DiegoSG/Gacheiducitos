@tool
extends Camera2D
class_name BoundedCamera

@export var level_bounds: Vector2 = Vector2(3840, 2160)
@export var target_node: Node2D

func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 5.0
	_connect_boundary_manager()
	if not Engine.is_editor_hint():
		snap_to_target()

func _connect_boundary_manager() -> void:
	var tree = get_tree()
	if tree:
		var managers = tree.get_nodes_in_group("world_boundary_managers")
		if not managers.is_empty():
			var mgr = managers[0]
			if mgr.has_method("get_level_bounds"):
				setup_bounds(mgr.get_level_bounds())
			if mgr.has_signal("bounds_changed") and not mgr.bounds_changed.is_connected(setup_bounds):
				mgr.bounds_changed.connect(setup_bounds)
			return
			
	# Fallback si no hay WorldBoundaryManager en la escena
	setup_bounds(level_bounds)

func setup_bounds(bounds: Vector2) -> void:
	level_bounds = bounds
	limit_left = 0
	limit_top = 0
	limit_right = int(bounds.x)
	limit_bottom = int(bounds.y)
	reset_smoothing()
	force_update_scroll()

func snap_to_target() -> void:
	if is_instance_valid(target_node):
		global_position = target_node.global_position
	reset_smoothing()
	force_update_scroll()

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if is_instance_valid(target_node):
		global_position = target_node.global_position
