class_name DestroyNodeAction
extends ActionResource

## Removes (queue_free) or hides and disables a node in the level (e.g. breakable rocks, temporary barriers).

enum DestroyMode {
	QUEUE_FREE,      ## Safely removes the node from memory
	HIDE_AND_DISABLE ## Hides it and disables its collisions without destroying it
}

## Path to the target node
@export var target_node_path: NodePath

## Destruction mode
@export var mode: DestroyMode = DestroyMode.QUEUE_FREE

## Duration of a fade out before destroying/hiding (0 = instant)
@export var fade_duration: float = 0.0

func get_action_name() -> String:
	return "DestroyNodeAction (%s)" % str(target_node_path)

func execute(trigger_node: Node) -> void:
	if target_node_path.is_empty():
		push_warning("DestroyNodeAction: target_node_path is empty.")
		finished.emit()
		return
		
	var target: Node = trigger_node.get_node_or_null(target_node_path)
	if not is_instance_valid(target):
		push_warning("DestroyNodeAction: Node not found at %s" % str(target_node_path))
		finished.emit()
		return
		
	if fade_duration > 0.0 and target is CanvasItem:
		var canvas_item: CanvasItem = target as CanvasItem
		var tween: Tween = trigger_node.create_tween()
		tween.tween_property(canvas_item, "modulate:a", 0.0, fade_duration)
		if wait_to_finish:
			await tween.finished
			_finalize_destroy(target)
			finished.emit()
			return
		else:
			tween.finished.connect(func() -> void: _finalize_destroy(target))
			finished.emit()
			return
	else:
		_finalize_destroy(target)
		finished.emit()

func _finalize_destroy(target: Node) -> void:
	if not is_instance_valid(target):
		return
	AudioManager.play_sfx(&"sfx_destroy_node")
		
	if mode == DestroyMode.QUEUE_FREE:
		target.queue_free()
	else:
		if target is CanvasItem:
			(target as CanvasItem).visible = false
		_disable_collision_recursively(target)

func _disable_collision_recursively(node: Node) -> void:
	if node is CollisionShape2D or node is CollisionPolygon2D:
		node.set_deferred("disabled", true)
	for child: Node in node.get_children():
		_disable_collision_recursively(child)
