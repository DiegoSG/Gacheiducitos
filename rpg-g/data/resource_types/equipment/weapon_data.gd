extends EquipmentData
class_name WeaponData

## Melee weapon. Damage is added to PlayerStats.get_strength().

@export var damage: int = 1
## Seconds to wait between attacks (in addition to the swing duration).
@export_range(0.0, 3.0, 0.01, "suffix:s") var cooldown: float = 0.0
## Size of the hit zone (width x reach), in px.
@export var reach: Vector2 = Vector2(60, 60)
@export var knockback: float = 300.0
## Hit visual (if empty, the owner's is used).
@export var slash_texture: Texture2D
@export_group("Status Effect")
@export var status_effect: StatusEffectData
@export_range(0, 100) var status_chance: float = 0.0

func _init() -> void:
	kind = Kind.MELEE
