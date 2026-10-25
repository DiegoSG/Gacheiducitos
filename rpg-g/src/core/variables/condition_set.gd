class_name ConditionSet
extends Resource

## Conjunto de condiciones combinadas con AND (ALL) u OR (ANY).

enum Mode { ALL, ANY }

@export var conditions: Array[Condition] = []
@export var mode: Mode = Mode.ALL

## Un conjunto vacío se considera verdadero.
func evaluate() -> bool:
	if conditions.is_empty():
		return true
	for condition: Condition in conditions:
		if condition == null:
			continue
		var result: bool = condition.evaluate()
		if mode == Mode.ANY and result:
			return true
		if mode == Mode.ALL and not result:
			return false
	return mode == Mode.ALL
