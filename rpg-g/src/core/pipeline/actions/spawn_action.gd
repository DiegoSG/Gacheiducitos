class_name SpawnAction
extends ActionResource

## Instantiates (Spawns) a scene during the sequence.

## The PackedScene you want to spawn/instantiate.
@export var scene_to_spawn: PackedScene

## The node that will become the parent of the spawned scene. If empty, the trigger's parent will be used.
@export var parent_path: NodePath = "."

## Position offset where the object will spawn.
@export var spawn_position: Vector2 = Vector2.ZERO

## If true, the spawned object's position will be added relative to the parent's position.
@export var relative_to_parent: bool = true

func get_action_name() -> String:
	return "SpawnAction (%s)" % (scene_to_spawn.resource_path.get_file() if scene_to_spawn else "None")

func execute(trigger_node: Node) -> void:
	if not scene_to_spawn:
		finished.emit()
		return
	
	var parent_node = trigger_node.get_node_or_null(parent_path)
		
	# Si no configuraron bien el NodePath parent_path usamos el nivel o mundo como fallback, 
	# o simplemente el trigger_node padre
	if not parent_node:
		parent_node = trigger_node.get_parent()
		
	if parent_node:
		var instance = scene_to_spawn.instantiate()
		parent_node.add_child(instance)
		
		# Set position
		if instance is Node2D:
			if relative_to_parent:
				instance.position = spawn_position
			else:
				instance.global_position = spawn_position
	
	finished.emit()
