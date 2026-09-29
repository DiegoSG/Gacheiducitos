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

func execute(_trigger_node: Node) -> void:
	if state == QuestState.START:
		NarrativeManager.start_quest(quest_id)
	else:
		NarrativeManager.complete_quest(quest_id)
	finished.emit()
