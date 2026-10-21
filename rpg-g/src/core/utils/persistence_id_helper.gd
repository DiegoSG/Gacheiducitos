@tool
class_name PersistenceIdHelper
extends RefCounted

## Static utility to generate unique, deterministic
## and reproducible persistence identifiers based on the scene path and the node's hierarchy.
##
## IMPORTANT: The generated ID is stable across runs because it is based on
## the scene file path and the node's hierarchical position (NOT on randi()).


static func generate_id(node: Node, prefix: String = "") -> String:
	if not node:
		return ""

	# 1. Stable root scene identifier (based on the .tscn file)
	var scene_id: String = "scene"
	var root: Node = node.owner
	if not root and node.get_tree():
		root = node.get_tree().current_scene

	if root:
		if not root.scene_file_path.is_empty():
			scene_id = root.scene_file_path.get_file().get_basename().to_snake_case()
		elif not root.name.is_empty():
			scene_id = root.name.to_snake_case()

	# 2. Strict hierarchical path within the scene (guarantees uniqueness among siblings)
	var rel_path: String = ""
	if root and root != node:
		rel_path = str(root.get_path_to(node))
	else:
		rel_path = str(node.get_path()) if node.is_inside_tree() else str(node.name)

	# 3. Deterministic 8-character MD5 hash (100% reproducible across runs)
	var full_signature: String = "%s:%s" % [scene_id, rel_path]
	var deterministic_hash: String = full_signature.md5_text().substr(0, 8)

	var tag: String = prefix if not prefix.is_empty() else node.name.to_snake_case()
	return "%s_%s_%s" % [scene_id, tag, deterministic_hash]


## Persistence key to use at runtime.
## If [param explicit_id] has a value, the state is permanent (saved with the game).
## If empty, returns an "ephemeral" key based on the node path: the state lasts
## only while the player stays in the level (WorldStateManager clears it on level change).
## Never assign the result to the exported persistence_id property: in @tool scripts
## it would be saved inside the scene.
static func runtime_key(node: Node, explicit_id: String) -> String:
	if not explicit_id.is_empty():
		return explicit_id
	if node.owner:
		return "ephemeral_" + str(node.owner.get_path_to(node))
	return str(node.get_path()) + "_ephemeral"
