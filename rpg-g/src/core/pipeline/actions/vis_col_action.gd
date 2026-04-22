class_name VisColAction
extends ActionResource
## Toggles the node's visibility and physics properties.

## The NodePath pointing to the object you want to affect.
@export var target_node: NodePath

@export_group("Propiedades")
## Sets the Visible property of the node.
@export var is_visible: bool = true

## Disables or enables ALL collision shapes inside this node (searches recursively).
@export var collisions_enabled: bool = true

func get_action_name() -> String:
	return "VisColAction: Vis(%s) Col(%s)" % [is_visible, collisions_enabled]

func execute(trigger_node: Node) -> void:
	if target_node.is_empty():
		finished.emit()
		return
		
	var t_node = trigger_node.get_node_or_null(target_node)
	if not t_node:
		print("VisColAction: No se encontró target ", target_node)
		finished.emit()
		return
		
	# Toggle Visibilidad
	if "visible" in t_node:
		t_node.visible = is_visible
		
	# Toggle Colisiones recursivo (busca CollisionShape2D/CollisionPolygon2D)
	_set_collisions_recursive(t_node, collisions_enabled)
	
	finished.emit()

func _set_collisions_recursive(node: Node, enabled: bool) -> void:
	# En Godot, las colisiones se apagan poniendo disabled = true
	if node is CollisionShape2D or node is CollisionPolygon2D:
		node.set_deferred("disabled", not enabled)
		
	for child in node.get_children():
		_set_collisions_recursive(child, enabled)
