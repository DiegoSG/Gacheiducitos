class_name VariableAction
extends ActionResource

## Modifica una variable de GameVariables (solo rutas flag.*).

enum Operation { SET, ADD, TOGGLE }

## Ruta de la variable, por ejemplo "flag.puerta_abierta".
@export var var_path: String = "flag."
@export var operation: Operation = Operation.SET
## SET: valor a asignar (true/false, número o texto). ADD: cantidad a sumar. TOGGLE: se ignora.
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
