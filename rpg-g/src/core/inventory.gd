extends Node

signal inventory_changed

## Id del "objeto" oro. El oro vive SOLO en PlayerStats.gold; este id se enruta allí
## y nunca se guarda en `items`.
const GOLD_ITEM_ID: String = "gold_coins"

# Dictionary to store items: {"item_id": amount}
var items: Dictionary = {}

func add_item(item_id: String, amount: int = 1) -> void:
	if item_id.is_empty() or amount <= 0:
		return

	if item_id == GOLD_ITEM_ID:
		PlayerStats.add_gold(amount)
		return

	items[item_id] = int(items.get(item_id, 0)) + amount
	inventory_changed.emit()

## Atómico: si no hay cantidad suficiente devuelve false y no quita nada.
func remove_item(item_id: String, amount: int = 1) -> bool:
	if item_id.is_empty() or amount <= 0:
		return false

	if item_id == GOLD_ITEM_ID:
		return PlayerStats.remove_gold(amount)

	if get_item_count(item_id) < amount:
		return false

	var remaining: int = int(items[item_id]) - amount
	if remaining <= 0:
		items.erase(item_id)
	else:
		items[item_id] = remaining

	inventory_changed.emit()
	return true

func use_item(item_id: String) -> bool:
	if get_item_count(item_id) <= 0:
		return false

	var data: ItemData = ItemDatabase.get_item(item_id)
	if not data or data.type != ItemData.ItemType.CONSUMABLE:
		return false

	var consumed: bool = false
	if data.heal_amount > 0:
		PlayerStats.heal(data.heal_amount)
		consumed = true
	if data.damage_amount > 0:
		PlayerStats.take_damage(data.damage_amount)
		consumed = true

	if consumed:
		remove_item(item_id, 1)
		return true

	return false

## Copia de los objetos del inventario. Nunca contiene oro.
func get_items() -> Dictionary:
	return items.duplicate()

func get_item_count(item_id: String) -> int:
	if item_id == GOLD_ITEM_ID:
		return PlayerStats.gold
	return int(items.get(item_id, 0))

func has_item_amount(item_id: String, amount: int) -> bool:
	if amount <= 0:
		return true
	return get_item_count(item_id) >= amount

func create_snapshot() -> Dictionary:
	return items.duplicate(true)

func restore_snapshot(snapshot: Dictionary) -> void:
	items = snapshot.duplicate(true)
	# Migración de saves antiguos: el oro se guardaba dentro de items; ahora vive solo en PlayerStats
	items.erase(GOLD_ITEM_ID)
	inventory_changed.emit()
