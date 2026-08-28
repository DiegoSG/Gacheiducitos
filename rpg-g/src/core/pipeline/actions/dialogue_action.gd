class_name DialogueAction
extends ActionResource

## Shows a dialogue using the DialogueManager.

## The .dialogue resource file containing the written dialogue.
@export var dialogue_resource: Resource

## The knot or starting title you want to trigger (default is Usually ~ start).
@export var dialogue_title: String = "start"

func get_action_name() -> String:
	return "DialogueAction (%s)" % dialogue_title

func execute(trigger_node: Node) -> void:
	# Using the global DialogueManager (autoload)
	var dialogue_manager = trigger_node.get_tree().root.get_node_or_null("DialogueManager")
	
	if dialogue_manager and dialogue_resource:
		# Check if the dialogue_manager has show_example_balloon or a similar method
		# Most common usage is DialogueManager.show_dialogue_balloon(resource, title)
		# Or if using the addon's default UI:
		dialogue_manager.show_dialogue_balloon(dialogue_resource, dialogue_title)
		
		# We need to wait for the dialogue to finish.
		# DialogueManager usually emits a signal when the dialogue balloon is closed.
		# Wait, common signal is 'dialogue_finished'.
		if dialogue_manager.has_signal("dialogue_ended"):
			if not dialogue_manager.is_connected("dialogue_ended", _on_dialogue_ended):
				dialogue_manager.dialogue_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)
			return
	
	print("DialogueAction: Dialogue setup failed for ", dialogue_title)
	finished.emit()

func _on_dialogue_ended(_resource: Resource) -> void:
	finished.emit()
