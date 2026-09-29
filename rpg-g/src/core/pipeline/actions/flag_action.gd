class_name FlagAction
extends ActionResource

## Modifies a narrative flag in the NarrativeManager.

## The exact name of the flag defined in NarrativeManager
@export var flag_id: String = ""

## The new value to set. Type 'true' or 'false' for booleans, or a number for integers/floats.
@export var value: String = "true"

func get_action_name() -> String:
	return "FlagAction (%s = %s)" % [flag_id, value]

func execute(_trigger_node: Node) -> void:
	NarrativeManager.set_flag(flag_id, ActionResource.parse_value(value))
	finished.emit()
