extends Resource
class_name EquipmentData

## Base data for an equipment item (see design/Sistema_Armas_y_Escudo.md).
## MELEE and THROWABLE go in the weapon slots; SHIELD goes in the shield slot.

enum Kind { MELEE, THROWABLE, SHIELD }

@export var kind: Kind = Kind.MELEE

func is_weapon() -> bool:
	return kind == Kind.MELEE or kind == Kind.THROWABLE
