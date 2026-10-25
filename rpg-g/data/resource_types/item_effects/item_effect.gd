extends Resource
class_name ItemEffect

## Efecto base de un item consumible. Las subclases sobreescriben apply() y describe().

func apply() -> void:
	pass

func describe() -> String:
	return ""
