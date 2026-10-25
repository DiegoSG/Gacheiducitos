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

## Convierte un texto de configuración al tipo adecuado:
## true/false/verdadero/falso (sin distinguir mayúsculas) -> bool, entero -> int, decimal -> float,
## cualquier otro caso -> el String original.
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

## Dispara un evento global vía GameManager.trigger_event. No hace nada si el nombre está vacío.
func emit_game_event(event_name: String) -> void:
	if event_name.is_empty():
		return
	GameManager.trigger_event(event_name)

## Emitted when the action finishes its logic.
@warning_ignore("unused_signal")
signal finished
