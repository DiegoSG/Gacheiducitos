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

## Visibilidad de las etiquetas de debug (F3). Estado único compartido con LevelPortal.
static var debug_visuals_visible: bool = false

func _ready() -> void:
	add_to_group("arrival_points")
	_update_visuals()
	
	if not Engine.is_editor_hint():
		# En runtime ocultar por defecto a menos que debug esté activo
		_set_debug_visibility(debug_visuals_visible)

func _unhandled_input(event: InputEvent) -> void:
	handle_debug_input(self, event)

## Procesa F3 para el nodo dado. Al marcar el input como manejado, solo un nodo
## (el primero en recibirlo) alterna la visibilidad por pulsación.
static func handle_debug_input(node: Node, event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event.is_action_pressed("debug_toggle"):
		node.get_viewport().set_input_as_handled()
		toggle_debug_visuals(node.get_tree())

## Alterna las etiquetas de debug de todos los puntos de llegada (portales y spawn points)
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
		warnings.append("El 'arrival_id' está vacío. Debe tener un identificador asignado.")
	else:
		var root_node: Node = find_scene_root(self)
		if root_node and count_arrival_id(root_node, arrival_id) > 1:
			warnings.append("Existe otro nodo en esta escena con el mismo arrival_id ('%s'). Los arrival_id deben ser únicos." % arrival_id)
	return warnings

## Devuelve la raíz de la escena que contiene al nodo (editor: escena editada; runtime: owner o ancestro superior)
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

## Cuenta cuántos nodos bajo 'root' (incluido) declaran el arrival_id dado
static func count_arrival_id(root: Node, id: String) -> int:
	var count: int = 0
	if "arrival_id" in root and root.arrival_id == id:
		count += 1
	for child: Node in root.get_children():
		count += count_arrival_id(child, id)
	return count
