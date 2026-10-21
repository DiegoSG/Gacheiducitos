extends Node

## Isolated inventory test: no save menu, focus on the list with the first row
## selected on open, and the selection is kept on refresh.

@onready var inventory_ui: CanvasLayer = $InventoryUI

func _ready() -> void:
	print("[TestInventoryUI] Starting...")
	var ok: bool = true
	Inventory.restore_snapshot({})
	Inventory.add_item("test_item_a", 2)
	Inventory.add_item("test_item_b", 1)
	await get_tree().process_frame

	if inventory_ui.get_node_or_null("Control/SaveMenuUI") != null:
		push_error("[TestInventoryUI] The inventory still contains SaveMenuUI")
		ok = false

	inventory_ui.open_inventory()
	await get_tree().process_frame

	var item_list: ItemList = inventory_ui.get_node("Control/Panel/ItemList") as ItemList
	if get_viewport().gui_get_focus_owner() != item_list:
		push_error("[TestInventoryUI] The list does not have focus when opened")
		ok = false
	if item_list.get_selected_items() != PackedInt32Array([0]):
		push_error("[TestInventoryUI] The first row is not selected when opened")
		ok = false

	item_list.select(1)
	inventory_ui.refresh_ui()
	if item_list.get_selected_items() != PackedInt32Array([1]):
		push_error("[TestInventoryUI] Selection was lost on refresh")
		ok = false

	inventory_ui.close_inventory()
	print("[TestInventoryUI] ", "Test passed." if ok else "Test FAILED.")
	get_tree().quit(0 if ok else 1)
