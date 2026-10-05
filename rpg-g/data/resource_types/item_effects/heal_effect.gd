extends ItemEffect
class_name HealEffect

@export var amount: int = 0

func apply() -> void:
	AudioManager.play_ui(&"sfx_item_heal")
	PlayerStats.heal(amount)

func describe() -> String:
	return "Cura %d" % amount
