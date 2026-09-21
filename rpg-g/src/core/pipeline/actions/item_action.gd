class_name ItemAction
extends ActionResource

## Acción que añade o remueve ítems del inventario global.
## Compatible con el pipeline de GameTrigger y DialogueEvent.

@export var item_id: String = ""
@export var amount: int = 1
@export_enum("add", "remove") var operation: String = "add"
@export var show_feedback: bool = true

func get_action_name() -> String:
	return "ItemAction (%s %s x%d)" % [operation, item_id, amount]

func execute(trigger_node: Node) -> void:
	if not trigger_node:
		push_warning("ItemAction: trigger_node es null.")
		finished.emit()
		return
	if item_id.is_empty() or amount <= 0:
		finished.emit()
		return

	var inv = trigger_node.get_node_or_null("/root/Inventory")
	var item_db = trigger_node.get_node_or_null("/root/ItemDatabase")

	if not inv:
		push_warning("ItemAction: Autoload /root/Inventory no encontrado.")
		finished.emit()
		return

	if operation == "add":
		inv.add_item(item_id, amount)
		if show_feedback and item_db:
			var data: ItemData = item_db.get_item(item_id)
			if data:
				LootFeedbackManager.trigger_toast(data, amount)
	elif operation == "remove":
		inv.remove_item(item_id, amount)

	finished.emit()
