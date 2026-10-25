class_name Condition
extends Resource

## Comparación de una variable de GameVariables contra un valor. Ej: "flag.puerta_abierta" == true.

enum Operator { EQUAL, NOT_EQUAL, GREATER, GREATER_EQUAL, LESS, LESS_EQUAL }

## Ruta de la variable (flag.x, quest.id, player.gold, item.id, status.id...)
@export var var_path: String = ""
@export var operator: Operator = Operator.EQUAL
## Valor a comparar; se interpreta con ActionResource.parse_value (true/false, números o texto).
@export var value: String = "true"

func evaluate() -> bool:
	if var_path.is_empty():
		return true
	var actual: Variant = GameVariables.get_var(var_path)
	var expected: Variant = ActionResource.parse_value(value)
	var numeric: bool = _is_number(actual) and _is_number(expected)
	match operator:
		Operator.EQUAL:
			return _equals(actual, expected, numeric)
		Operator.NOT_EQUAL:
			return not _equals(actual, expected, numeric)
	# Los operadores de orden solo tienen sentido con números
	if not numeric:
		return false
	var a: float = float(actual)
	var b: float = float(expected)
	match operator:
		Operator.GREATER:
			return a > b
		Operator.GREATER_EQUAL:
			return a >= b
		Operator.LESS:
			return a < b
		Operator.LESS_EQUAL:
			return a <= b
	return false

func _equals(actual: Variant, expected: Variant, numeric: bool) -> bool:
	if numeric:
		return is_equal_approx(float(actual), float(expected))
	return str(actual) == str(expected)

func _is_number(v: Variant) -> bool:
	return v is int or v is float
