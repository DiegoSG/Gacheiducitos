class_name GoldAction
extends ActionResource

## Action that adds or subtracts gold coins from the player in PlayerStats.
## Compatible with the GameTrigger, DialogueEvent and OnEventListener pipeline.

@export_group("Gold Configuration")
## Amount of gold to add or subtract
@export_range(1, 99999) var amount: int = 10
## Operation: 'add' (add gold) or 'remove' (atomic subtraction)
@export_enum("add", "remove") var operation: String = "add"
## If true, shows the toast notification on the HUD when receiving the gold
@export var show_feedback: bool = true

@export_group("Event Triggers (Optional)")
## Global event fired via GameManager.trigger_event if the action completes successfully.
@export var on_success_event: String = ""
## Global event fired via GameManager.trigger_event if there is not enough gold to pay.
@export var on_fail_event: String = ""

func get_action_name() -> String:
	return "GoldAction (%s %d gold)" % [operation, amount]

func execute(trigger_node: Node) -> void:
	if not trigger_node:
		push_warning("GoldAction: trigger_node is null.")
		emit_game_event(on_fail_event)
		finished.emit()
		return

	if amount <= 0:
		push_warning("GoldAction: amount must be greater than 0.")
		emit_game_event(on_fail_event)
		finished.emit()
		return

	if operation == "add":
		PlayerStats.add_gold(amount)
		if show_feedback:
			var coin_res: ItemData = ItemDatabase.get_item(Inventory.GOLD_ITEM_ID)
			if coin_res:
				LootFeedbackManager.trigger_toast(coin_res, amount)
		emit_game_event(on_success_event)
	elif operation == "remove":
		if PlayerStats.remove_gold(amount):
			emit_game_event(on_success_event)
		else:
			# Failure: not enough gold (nothing is deducted)
			emit_game_event(on_fail_event)

	finished.emit()
