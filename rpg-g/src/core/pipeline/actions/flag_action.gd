class_name FlagAction
extends ActionResource

## Modifies a narrative flag in the NarrativeManager.

## The exact name of the flag defined in NarrativeManager
@export var flag_id: String = ""

## The new value to set. Type 'true' or 'false' for booleans, or a number for integers.
@export var value: String = "true"

func get_action_name() -> String:
	return "FlagAction (%s = %s)" % [flag_id, value]

func execute(trigger_node: Node) -> void:
	var tree = trigger_node.get_tree()
	var narrative_manager = tree.root.get_node_or_null("NarrativeManager")
	
	if narrative_manager:
		# Convert value from string to appropriate type
		var typed_value = value
		if value.to_lower() == "true":
			typed_value = true
		elif value.to_lower() == "false":
			typed_value = false
		elif value.is_valid_int():
			typed_value = value.to_int()
		
		narrative_manager.set_flag(flag_id, typed_value)
	else:
		print("FlagAction: NarrativeManager not found!")
		
	finished.emit()
