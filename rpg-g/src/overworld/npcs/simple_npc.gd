extends Actionable
class_name SimpleNPC

@export var npc_name: String = "NPC"
@export var dialogue_resource: DialogueResource
@export var dialogue_start_title: String = "start"

func _init() -> void:
	allow_during_alert = false

func action() -> void:
	if not allow_during_alert and AlertSystem.is_in_alert():
		AudioManager.play_sfx(&"sfx_npc_busy_alert")
		return
		
	if not dialogue_resource:
		push_warning("NPC '%s' is missing a dialogue resource." % npc_name)
		return
		
	AudioManager.play_ui(&"sfx_npc_talk")
	DialogueManager.show_dialogue_balloon(dialogue_resource, dialogue_start_title)
