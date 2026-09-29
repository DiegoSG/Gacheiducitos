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
		push_warning("DialogueAction: dialogue_resource no asignado (título '%s')." % dialogue_title)
		finished.emit()
		return

	DialogueManager.show_dialogue_balloon(dialogue_resource, dialogue_title)
	# Esperar a que el globo de diálogo se cierre para liberar la secuencia
	if not DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)

func _on_dialogue_ended(_resource: Resource) -> void:
	finished.emit()
