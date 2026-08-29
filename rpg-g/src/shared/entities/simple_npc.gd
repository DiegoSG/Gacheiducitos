extends Actionable
class_name SimpleNPC

@export var npc_name: String = "NPC"
@export var dialogue_resource: DialogueResource
@export var dialogue_start_title: String = "start"

const BALLOON_SCENE = preload("res://src/ui/balloon/example_balloon.tscn")

func _init() -> void:
	allow_during_alert = false

func action() -> void:
	if not allow_during_alert and GameManager and GameManager.is_in_alert():
		print("SimpleNPC: No se puede hablar con '%s' durante el estado de alerta." % npc_name)
		return
		
	if not dialogue_resource:
		push_warning("NPC '%s' is missing a dialogue resource." % npc_name)
		return
		
	var balloon = BALLOON_SCENE.instantiate()
	get_tree().root.add_child(balloon)
	balloon.start(dialogue_resource, dialogue_start_title)
