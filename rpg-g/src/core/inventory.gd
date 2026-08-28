extends Node

signal inventory_changed

# Dictionary to store items: {"item_id": amount}
var items: Dictionary = {}

func add_item(item_id: String, amount: int = 1) -> void:
	if not item_id or item_id.is_empty():
		return
		
	if items.has(item_id):
		items[item_id] += amount
	else:
		items[item_id] = amount
		
	inventory_changed.emit()
	print("Objeto recogido: ", item_id, " x", amount)

func remove_item(item_id: String, amount: int = 1) -> bool:
	if not items.has(item_id):
		return false
		
	items[item_id] -= amount
	if items[item_id] <= 0:
		items.erase(item_id)
		
	inventory_changed.emit()
	return true

func get_items() -> Dictionary:
	return items.duplicate()
