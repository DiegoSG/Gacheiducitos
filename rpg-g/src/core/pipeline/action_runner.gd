class_name ActionRunner
extends RefCounted

## Runs a list of ActionResource in order, respecting wait_to_finish.
## Single execution point for GameTrigger, DialogueEvent, PressurePlate and SwitchInteractable.

## Runs [param actions] in order using [param context] as the executing node.
## If the action has wait_to_finish = true, waits for its finished signal before continuing;
## if false, fires it and moves on to the next without blocking.
## If the context leaves the tree (or is freed) while waiting, the sequence is aborted.
static func run(actions: Array[ActionResource], context: Node) -> void:
	var is_first: bool = true
	for act: ActionResource in actions:
		if act == null:
			continue
		if not is_first and not _is_context_alive(context):
			return
		is_first = false

		if not act.wait_to_finish:
			act.execute(context)
			continue

		var state: Dictionary = {"waiting": true}
		var on_action_done: Callable = func() -> void: state.waiting = false
		act.finished.connect(on_action_done, CONNECT_ONE_SHOT)
		act.execute(context)

		while state.waiting:
			if not _is_context_alive(context):
				if act.finished.is_connected(on_action_done):
					act.finished.disconnect(on_action_done)
				return
			await context.get_tree().process_frame

static func _is_context_alive(context: Node) -> bool:
	return is_instance_valid(context) and context.is_inside_tree()
