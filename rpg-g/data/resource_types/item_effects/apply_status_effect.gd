extends ItemEffect
class_name ApplyStatusEffect

@export var status: StatusEffectData

func apply() -> void:
	if status:
		PlayerStats.apply_status(status)

func describe() -> String:
	return "Aplica %s" % (status.display_name if status else "?")
