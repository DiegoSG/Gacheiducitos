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

## Converts a config text to the appropriate type:
## true/false/verdadero/falso (case-insensitive) -> bool, integer -> int, decimal -> float,
## any other input -> the original String.
static func parse_value(text: String) -> Variant:
	var lowered: String = text.to_lower()
	if lowered == "true" or lowered == "verdadero":
		return true
	if lowered == "false" or lowered == "falso":
		return false
	if text.is_valid_int():
		return text.to_int()
	if text.is_valid_float():
		return text.to_float()
	return text

## Fires a global event via GameManager.trigger_event. Does nothing if the name is empty.
func emit_game_event(event_name: String) -> void:
	if event_name.is_empty():
		return
	GameManager.trigger_event(event_name)

## Emitted when the action finishes its logic.
@warning_ignore("unused_signal")
signal finished
