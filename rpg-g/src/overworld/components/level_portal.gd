@tool
extends Area2D
class_name LevelPortal

signal portal_triggered(target_level_path: String, target_arrival_id: String)

@export_file("*.tscn") var target_level_path: String = "":
	set(value):
		target_level_path = value
		update_configuration_warnings()

## ID de salida: ID de llegada al que se conectará en el nivel destino
@export var exit_id: String = "":
	set(value):
		exit_id = value
		_update_visuals()
		update_configuration_warnings()

## ID de llegada: Identificador único propio para recibir jugadores que entren a este nivel
@export var arrival_id: String = "":
	set(value):
		arrival_id = value
		_update_visuals()
		update_configuration_warnings()

@onready var exit_label: Label = $ExitIdLabel if has_node("ExitIdLabel") else null
@onready var spawn_point_node: Marker2D = $SpawnPoint if has_node("SpawnPoint") else null
@onready var arrival_label: Label = $SpawnPoint/ArrivalIdLabel if has_node("SpawnPoint/ArrivalIdLabel") else null

var _is_triggered: bool = false
static var debug_visuals_visible: bool = false

func _ready() -> void:
	add_to_group("arrival_points")
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)
		_set_debug_visibility(debug_visuals_visible)
	_update_visuals()

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			get_viewport().set_input_as_handled()
			toggle_debug_visuals()

func toggle_debug_visuals() -> void:
	debug_visuals_visible = not debug_visuals_visible
	for node in get_tree().get_nodes_in_group("arrival_points"):
		if node.has_method("_set_debug_visibility"):
			node._set_debug_visibility(debug_visuals_visible)

func _set_debug_visibility(p_visible: bool) -> void:
	if has_node("ExitIdLabel"):
		$ExitIdLabel.visible = p_visible
	if has_node("SpawnPoint/ArrivalIdLabel"):
		$SpawnPoint/ArrivalIdLabel.visible = p_visible

func _update_visuals() -> void:
	if not is_node_ready():
		await ready
	if has_node("ExitIdLabel"):
		$ExitIdLabel.text = exit_id
		if Engine.is_editor_hint():
			$ExitIdLabel.visible = true
	if has_node("SpawnPoint/ArrivalIdLabel"):
		$SpawnPoint/ArrivalIdLabel.text = arrival_id
		if Engine.is_editor_hint():
			$SpawnPoint/ArrivalIdLabel.visible = true

func _on_body_entered(body: Node2D) -> void:
	if _is_triggered or Engine.is_editor_hint():
		return
		
	if body.name == "Player" or body.is_in_group("player"):
		_is_triggered = true
		portal_triggered.emit(target_level_path, exit_id)
		var game_manager = get_node_or_null("/root/GameManager")
		if game_manager and game_manager.has_method("change_level"):
			game_manager.change_level(target_level_path, exit_id)

func get_spawn_position() -> Vector2:
	if has_node("SpawnPoint"):
		return $SpawnPoint.global_position
	return global_position

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if target_level_path.strip_edges().is_empty():
		warnings.append("Debe seleccionar un 'target_level_path' (escena destino).")
	if exit_id.strip_edges().is_empty():
		warnings.append("Debe asignar un 'exit_id' que apunte al arrival_id en el nivel destino.")
	if arrival_id.strip_edges().is_empty():
		warnings.append("Debe asignar un 'arrival_id' único para este portal.")
	else:
		var root_node: Node = null
		if Engine.is_editor_hint() and get_tree() and get_tree().edited_scene_root:
			root_node = get_tree().edited_scene_root
		elif get_owner():
			root_node = get_owner()
		elif get_parent():
			root_node = get_parent()
			while root_node.get_parent() and not (root_node.get_parent() is Window):
				root_node = root_node.get_parent()
				
		if root_node:
			var duplicates = _find_duplicate_arrival_ids(root_node, arrival_id)
			if duplicates > 1:
				warnings.append("Existe otro portal o spawn point con el mismo arrival_id ('%s'). Deben ser únicos." % arrival_id)
	return warnings

func _find_duplicate_arrival_ids(node: Node, target_id: String) -> int:
	var count: int = 0
	if "arrival_id" in node and node.arrival_id == target_id:
		count += 1
	for child in node.get_children():
		count += _find_duplicate_arrival_ids(child, target_id)
	return count
