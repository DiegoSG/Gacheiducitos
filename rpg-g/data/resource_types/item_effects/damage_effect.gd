extends ItemEffect
class_name DamageEffect

@export var amount: int = 0

func apply() -> void:
	PlayerStats.take_damage(amount)

func describe() -> String:
	return "Dano %d" % amount
