class_name ActionResource
extends Resource

## The base class for all actions in an array.
## If true, the system will wait for this action's 'finished' signal before moving to the next.
@export var wait_to_finish: bool = true

## Returns a debug name for this action
func get_action_name() -> String:
	return "BaseAction"

## Executes the action logic.
## [param trigger_node] The GameTrigger Node that is running this action.
func execute(_trigger_node: Node) -> void:
	# Default behavior is just to finish immediately
	finished.emit()

## Emitted when the action finishes its logic.
@warning_ignore("unused_signal")
signal finished
