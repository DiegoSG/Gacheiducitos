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

func use_item(item_id: String) -> bool:
	if not items.has(item_id) or items[item_id] <= 0:
		return false
		
	var item_db := ItemDatabase
	if not item_db:
		return false
		
	var data: ItemData = item_db.get_item(item_id)
	if not data or data.type != ItemData.ItemType.CONSUMABLE:
		return false
		
	var stats := PlayerStats
	var consumed: bool = false
	
	if stats:
		if data.heal_amount > 0:
			stats.heal(data.heal_amount)
			consumed = true
		if data.damage_amount > 0:
			stats.take_damage(data.damage_amount)
			consumed = true
			
	if consumed:
		remove_item(item_id, 1)
		return true
		
	return false

func get_items() -> Dictionary:
	return items.duplicate()

func get_item_count(item_id: String) -> int:
	return items.get(item_id, 0)

func has_item_amount(item_id: String, amount: int) -> bool:
	if amount <= 0:
		return true
	return get_item_count(item_id) >= amount

func create_snapshot() -> Dictionary:
	return items.duplicate(true)

func restore_snapshot(snapshot: Dictionary) -> void:
	items = snapshot.duplicate(true)
	inventory_changed.emit()
	print("Inventory: Snapshot restaurado -> Items: ", items)
