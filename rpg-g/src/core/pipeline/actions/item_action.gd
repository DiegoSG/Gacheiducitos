class_name ItemAction
extends ActionResource

## Action that adds or removes items from the global inventory.
## Compatible with the GameTrigger, DialogueEvent and OnEventListener pipeline.

@export_group("Item Configuration")
## Visual resource of the item to add or remove
@export var item: ItemData = null
## Number of items involved
@export_range(1, 999) var amount: int = 1
## Operation: 'add' (add to inventory) or 'remove' (atomic subtraction)
@export_enum("add", "remove") var operation: String = "add"
## If true, shows the toast notification on the HUD when receiving the item
@export var show_feedback: bool = true

@export_group("Event Triggers (Optional)")
## Global event fired via GameManager.trigger_event if the action completes successfully.
@export var on_success_event: String = ""
## Global event fired via GameManager.trigger_event if the action fails (e.g. not enough of the amount when removing).
@export var on_fail_event: String = ""

func get_action_name() -> String:
	var item_name: String = item.id if item and not item.id.is_empty() else "None"
	return "ItemAction (%s %s x%d)" % [operation, item_name, amount]

func execute(trigger_node: Node) -> void:
	if not trigger_node:
		push_warning("ItemAction: trigger_node is null.")
		emit_game_event(on_fail_event)
		finished.emit()
		return

	if not item or item.id.is_empty() or amount <= 0:
		push_warning("ItemAction: Item not configured or invalid amount.")
		emit_game_event(on_fail_event)
		finished.emit()
		return

	if operation == "add":
		Inventory.add_item(item.id, amount)
		if show_feedback:
			LootFeedbackManager.trigger_toast(item, amount)
		emit_game_event(on_success_event)
	elif operation == "remove":
		# remove_item is atomic: if there is not enough of the amount it removes nothing and returns false
		if Inventory.remove_item(item.id, amount):
			emit_game_event(on_success_event)
		else:
			emit_game_event(on_fail_event)

	finished.emit()
