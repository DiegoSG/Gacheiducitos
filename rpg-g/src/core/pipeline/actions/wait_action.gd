class_name WaitAction
extends ActionResource

## Pauses the sequence for a specified time.

## Number of seconds your sequence will wait before continuing to the next action.
@export var duration: float = 1.0

func get_action_name() -> String:
	return "WaitAction (%fs)" % duration

func execute(trigger_node: Node) -> void:
	var tree: SceneTree = trigger_node.get_tree()
	if tree:
		var timer: SceneTreeTimer = tree.create_timer(duration)
		timer.timeout.connect(func() -> void: finished.emit())
	else:
		finished.emit()
