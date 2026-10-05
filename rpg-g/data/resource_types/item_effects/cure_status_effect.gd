extends ItemEffect
class_name CureStatusEffect

## Si cure_all es true, cura todos los estados; si no, solo el de status_id.
@export var status_id: String = ""
@export var cure_all: bool = true

func apply() -> void:
	AudioManager.play_ui(&"sfx_item_cure_status")
	if cure_all:
		PlayerStats.cure_all_statuses()
	else:
		PlayerStats.cure_status(status_id)

func describe() -> String:
	return "Cura todos los estados" if cure_all else "Cura %s" % status_id
