class_name SpawnAction
extends ActionResource

## Instantiates (spawns) a scene in the level using the position of a reference object or a marker.

## Scene to spawn (enemy, chest, item, effect, etc.)
@export var scene_to_spawn: PackedScene

@export_group("Spawn Location")
## Reference node for the position (Marker2D, Node2D, etc.). If assigned, spawns exactly at its global position.
@export var spawn_target_node: NodePath

## Optional extra offset from the target's or the parent's position
@export var offset: Vector2 = Vector2.ZERO

@export_group("Hierarchy")
## Node that will be the parent of the instantiated scene (optional). If empty, it is added to the current level's tree.
@export var parent_path: NodePath = ""

func get_action_name() -> String:
	return "SpawnAction (%s en %s)" % [
		scene_to_spawn.resource_path.get_file() if scene_to_spawn else "None",
		str(spawn_target_node) if not spawn_target_node.is_empty() else "Self"
	]

func execute(trigger_node: Node) -> void:
	if not scene_to_spawn:
		push_warning("SpawnAction: scene_to_spawn is not assigned.")
		finished.emit()
		return

	var target_ref: Node = null
	if not spawn_target_node.is_empty():
		target_ref = trigger_node.get_node_or_null(spawn_target_node)

	# If target_node was not assigned or not found, use trigger_node as the position
	var spawn_pos: Vector2 = Vector2.ZERO
	if target_ref is Node2D:
		spawn_pos = (target_ref as Node2D).global_position + offset
	elif trigger_node is Node2D:
		spawn_pos = (trigger_node as Node2D).global_position + offset

	# Determine the parent to add it to
	var parent_node: Node = null
	if not parent_path.is_empty():
		parent_node = trigger_node.get_node_or_null(parent_path)
	
	if not parent_node:
		# Add to the root of the current level / scene
		parent_node = trigger_node.get_tree().current_scene if trigger_node.get_tree() else trigger_node.get_parent()
		
	if parent_node:
		var instance: Node = scene_to_spawn.instantiate()
		parent_node.add_child(instance)
		AudioManager.play_sfx(&"sfx_spawn")
		
		if instance is Node2D:
			(instance as Node2D).global_position = spawn_pos

	finished.emit()
