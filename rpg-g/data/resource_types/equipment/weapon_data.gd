extends EquipmentData
class_name WeaponData

## Arma cuerpo a cuerpo. El daño se suma a PlayerStats.get_strength().

@export var damage: int = 1
## Segundos de espera entre ataques (además de la duración del golpe).
@export_range(0.0, 3.0, 0.01, "suffix:s") var cooldown: float = 0.0
## Tamaño de la zona de golpe (ancho x alcance), en px.
@export var reach: Vector2 = Vector2(60, 60)
@export var knockback: float = 300.0
## Visual del golpe (si está vacío se usa el del dueño).
@export var slash_texture: Texture2D
@export_group("Estado alterado")
@export var status_effect: StatusEffectData
@export_range(0, 100) var status_chance: float = 0.0

func _init() -> void:
	kind = Kind.MELEE
