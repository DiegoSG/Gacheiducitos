@tool
extends Marker2D
class_name ArrivalSpawnPoint

## Unique arrival identifier within the scene
@export var arrival_id: String = "":
	set(value):
		arrival_id = value
		_update_visuals()
		update_configuration_warnings()

@onready var arrival_label: Label = $ArrivalIdLabel if has_node("ArrivalIdLabel") else null

## Visibility of the debug labels (F3). Single state shared with LevelPortal.
static var debug_visuals_visible: bool = false

func _ready() -> void:
	add_to_group("arrival_points")
	_update_visuals()
	
	if not Engine.is_editor_hint():
		# At runtime, hide by default unless debug is active
		_set_debug_visibility(debug_visuals_visible)

func _unhandled_input(event: InputEvent) -> void:
	handle_debug_input(self, event)

## Processes F3 for the given node. When the input is marked as handled, only one node
## (the first one to receive it) toggles the visibility per press.
static func handle_debug_input(node: Node, event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event.is_action_pressed("debug_toggle"):
		node.get_viewport().set_input_as_handled()
		toggle_debug_visuals(node.get_tree())

## Toggles the debug labels of all arrival points (portals and spawn points)
static func toggle_debug_visuals(tree: SceneTree) -> void:
	debug_visuals_visible = not debug_visuals_visible
	for node: Node in tree.get_nodes_in_group("arrival_points"):
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
		warnings.append("The 'arrival_id' is empty. It must have an identifier assigned.")
	else:
		var root_node: Node = find_scene_root(self)
		if root_node and count_arrival_id(root_node, arrival_id) > 1:
			warnings.append("Another node in this scene has the same arrival_id ('%s'). arrival_id values must be unique." % arrival_id)
	return warnings

## Returns the root of the scene containing the node (editor: edited scene; runtime: owner or top ancestor)
static func find_scene_root(node: Node) -> Node:
	if Engine.is_editor_hint() and node.get_tree() and node.get_tree().edited_scene_root:
		return node.get_tree().edited_scene_root
	if node.get_owner():
		return node.get_owner()
	var root_node: Node = node.get_parent()
	if root_node:
		while root_node.get_parent() and not (root_node.get_parent() is Window):
			root_node = root_node.get_parent()
	return root_node

## Counts how many nodes under 'root' (included) declare the given arrival_id
static func count_arrival_id(root: Node, id: String) -> int:
	var count: int = 0
	if "arrival_id" in root and root.arrival_id == id:
		count += 1
	for child: Node in root.get_children():
		count += count_arrival_id(child, id)
	return count
