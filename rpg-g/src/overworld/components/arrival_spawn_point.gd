@tool
extends Marker2D
class_name ArrivalSpawnPoint

## Identificador único de llegada dentro de la escena
@export var arrival_id: String = "":
	set(value):
		arrival_id = value
		_update_visuals()
		update_configuration_warnings()

@onready var arrival_label: Label = $ArrivalIdLabel if has_node("ArrivalIdLabel") else null

static var debug_visuals_visible: bool = false

func _ready() -> void:
	add_to_group("arrival_points")
	_update_visuals()
	
	if not Engine.is_editor_hint():
		# En runtime ocultar por defecto a menos que debug esté activo
		_set_debug_visibility(debug_visuals_visible)

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
	if arrival_label:
		arrival_label.visible = p_visible

func _update_visuals() -> void:
	if not is_node_ready():
		await ready
	if has_node("ArrivalIdLabel"):
		arrival_label = $ArrivalIdLabel
		arrival_label.text = arrival_id
		if Engine.is_editor_hint():
			arrival_label.visible = true

func get_spawn_position() -> Vector2:
	return global_position

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if arrival_id.strip_edges().is_empty():
		warnings.append("El 'arrival_id' está vacío. Debe tener un identificador asignado.")
	else:
		# Comprobar si hay duplicados en el árbol de la escena actual
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
				warnings.append("Existe otro nodo en esta escena con el mismo arrival_id ('%s'). Los arrival_id deben ser únicos." % arrival_id)
	return warnings

func _find_duplicate_arrival_ids(node: Node, target_id: String) -> int:
	var count: int = 0
	if "arrival_id" in node and node.arrival_id == target_id:
		count += 1
	for child in node.get_children():
		count += _find_duplicate_arrival_ids(child, target_id)
	return count
