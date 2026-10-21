class_name DialogueAction
extends ActionResource

## Shows a dialogue using the DialogueManager.

## The .dialogue resource file containing the written dialogue.
@export var dialogue_resource: Resource

## The knot or starting title you want to trigger (default is Usually ~ start).
@export var dialogue_title: String = "start"

func get_action_name() -> String:
	return "DialogueAction (%s)" % dialogue_title

func execute(_trigger_node: Node) -> void:
	if dialogue_resource == null:
		push_warning("DialogueAction: dialogue_resource not assigned (title '%s')." % dialogue_title)
		finished.emit()
		return

	DialogueManager.show_dialogue_balloon(dialogue_resource, dialogue_title)
	# Wait for the dialogue balloon to close to release the sequence
	if not DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)

func _on_dialogue_ended(_resource: Resource) -> void:
	finished.emit()
