class_name QuestAction
extends ActionResource

## Modifies a quest state in the NarrativeManager.

enum QuestState { START, COMPLETE }

## The unique ID of the quest.
@export var quest_id: String = ""

## Whether to Start or Complete this quest.
@export var state: QuestState = QuestState.START

func get_action_name() -> String:
	return "QuestAction (%s: %s)" % [quest_id, "START" if state == QuestState.START else "COMPLETE"]

func execute(trigger_node: Node) -> void:
	var tree = trigger_node.get_tree()
	var narrative_manager = tree.root.get_node_or_null("NarrativeManager")
	
	if narrative_manager:
		if state == QuestState.START:
			narrative_manager.start_quest(quest_id)
		else:
			narrative_manager.complete_quest(quest_id)
	else:
		print("QuestAction: NarrativeManager not found!")
		
	finished.emit()
