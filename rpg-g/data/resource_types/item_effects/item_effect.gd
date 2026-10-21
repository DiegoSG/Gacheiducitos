extends Resource
class_name ItemEffect

## Base effect for a consumable item. Subclasses override apply() and describe().

func apply() -> void:
	pass

func describe() -> String:
	return ""
