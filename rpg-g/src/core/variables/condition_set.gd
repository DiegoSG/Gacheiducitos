class_name ConditionSet
extends Resource

## Set of conditions combined with AND (ALL) or OR (ANY).

enum Mode { ALL, ANY }

@export var conditions: Array[Condition] = []
@export var mode: Mode = Mode.ALL

## An empty set is considered true.
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
