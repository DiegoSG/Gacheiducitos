class_name VariableAction
extends ActionResource

## Modifies a GameVariables variable (only flag.* paths).

enum Operation { SET, ADD, TOGGLE }

## Variable path, for example "flag.puerta_abierta".
@export var var_path: String = "flag."
@export var operation: Operation = Operation.SET
## SET: value to assign (true/false, number or text). ADD: amount to add. TOGGLE: ignored.
@export var value: String = "true"

func get_action_name() -> String:
	return "VariableAction (%s %s %s)" % [var_path, Operation.keys()[operation], value]

func execute(_trigger_node: Node) -> void:
	match operation:
		Operation.SET:
			GameVariables.set_var(var_path, ActionResource.parse_value(value))
		Operation.ADD:
			GameVariables.add_var(var_path, value.to_float())
		Operation.TOGGLE:
			GameVariables.toggle_var(var_path)
	finished.emit()
