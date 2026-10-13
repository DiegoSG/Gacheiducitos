extends Resource
class_name EquipmentData

## Datos base de un equipo (ver design/Sistema_Armas_y_Escudo.md).
## MELEE y THROWABLE van en los slots de arma; SHIELD en el de escudo.

enum Kind { MELEE, THROWABLE, SHIELD }

@export var kind: Kind = Kind.MELEE

func is_weapon() -> bool:
	return kind == Kind.MELEE or kind == Kind.THROWABLE
