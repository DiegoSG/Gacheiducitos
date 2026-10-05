extends ItemEffect
class_name DamageEffect

@export var amount: int = 0

func apply() -> void:
	AudioManager.play_ui(&"sfx_item_damage")
	PlayerStats.take_damage(amount)

func describe() -> String:
	return "Dano %d" % amount
