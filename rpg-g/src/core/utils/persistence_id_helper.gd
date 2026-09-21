@tool
class_name PersistenceIdHelper
extends RefCounted

## Utilidad estática para generar identificadores únicos y consistentes de persistencia.

static func generate_id(node: Node, prefix: String = "") -> String:
	var scene_name: String = "scene"
	if node.owner and not node.owner.name.is_empty():
		scene_name = node.owner.name.to_snake_case()
	elif node.get_tree() and node.get_tree().current_scene:
		scene_name = node.get_tree().current_scene.name.to_snake_case()
		
	var node_name: String = node.name.to_snake_case()
	var tag: String = prefix if not prefix.is_empty() else node_name
	var random_hash: String = "%04x" % (randi() % 0xFFFF)
	
	return "%s_%s_%s" % [scene_name, tag, random_hash]
