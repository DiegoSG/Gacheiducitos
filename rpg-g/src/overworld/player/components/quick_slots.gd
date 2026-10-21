extends Node
class_name QuickSlots

## Quick slot component: 4 slots that each store an item_id.
## Consumable: used via Inventory.use_item; when depleted, the slot is emptied.
## Weapon/shield: swap. The slot's item gets equipped (the weapon in the active weapon slot, the shield
## in its own) and whatever was equipped there moves to this quick slot (or is left empty if there was nothing).

signal slot_changed(index: int, item_id: String)
signal slot_used(index: int, item_id: String)
signal equip_requested(index: int, item_id: String)

const SLOT_COUNT: int = 4

## Active instance (the one on the current level's Player); HUD and inventory query it.
static var instance: QuickSlots = null
## The data lives outside the node so it survives level changes (the Player is re-instantiated).
static var _slots: Array[String] = ["", "", "", ""]
## true while restore_snapshot re-emits slot_changed (when loading a save), so it stays silent.
static var is_restoring: bool = false

func _ready() -> void:
	instance = self
	Inventory.inventory_changed.connect(_on_inventory_changed)
	for i: int in SLOT_COUNT:
		slot_changed.emit(i, _slots[i])

func _exit_tree() -> void:
	if instance == self:
		instance = null
	if Inventory.inventory_changed.is_connected(_on_inventory_changed):
		Inventory.inventory_changed.disconnect(_on_inventory_changed)

func _unhandled_input(event: InputEvent) -> void:
	for i: int in SLOT_COUNT:
		if event.is_action_pressed("slot_%d" % (i + 1)):
			use_slot(i)
			get_viewport().set_input_as_handled()
			return

## Only weapons, shields and consumables can be assigned (keys, quest and material items cannot).
static func can_assign(item_id: String) -> bool:
	var data: ItemData = ItemDatabase.get_item(item_id)
	if data == null:
		return false
	if data.type == ItemData.ItemType.CONSUMABLE:
		return data.consumable
	return data.is_equippable()

func get_slot(index: int) -> String:
	if index < 0 or index >= SLOT_COUNT:
		return ""
	return _slots[index]

## Slot containing the item, or -1.
func find_slot(item_id: String) -> int:
	return _slots.find(item_id)

## Assigns the item to the slot (an item occupies only one slot). Returns false if it is not assignable.
func assign(index: int, item_id: String) -> bool:
	if index < 0 or index >= SLOT_COUNT or not can_assign(item_id):
		return false
	var previous: int = _slots.find(item_id)
	if previous != -1 and previous != index:
		AudioManager.play_ui(&"sfx_slot_reassign")
		_slots[previous] = ""
		slot_changed.emit(previous, "")
	_slots[index] = item_id
	slot_changed.emit(index, item_id)
	return true

func clear_slot(index: int) -> void:
	if index < 0 or index >= SLOT_COUNT or _slots[index].is_empty():
		return
	_slots[index] = ""
	AudioManager.play_ui(&"sfx_slot_clear")
	slot_changed.emit(index, "")

func use_slot(index: int) -> bool:
	var item_id: String = get_slot(index)
	var data: ItemData = null if item_id.is_empty() else ItemDatabase.get_item(item_id)
	var equipped_slot: String = Inventory.find_equipped_slot(item_id)
	if data == null or (Inventory.get_item_count(item_id) <= 0 and equipped_slot.is_empty()):
		AudioManager.play_sfx(&"sfx_slot_empty")
		return false
	if data.is_equippable():
		if not _swap_equipment(index, item_id, data, equipped_slot):
			return false
		equip_requested.emit(index, item_id)
	elif data.type == ItemData.ItemType.CONSUMABLE:
		if not Inventory.use_item(item_id):
			return false
		AudioManager.play_sfx(&"sfx_slot_use")
		# use_item already refreshed the slots via inventory_changed (and emptied this one if it was the last unit)
	else:
		return false
	slot_used.emit(index, item_id)
	return true

## Equips the slot's item and leaves whatever was equipped in the slot. Returns false if it failed.
func _swap_equipment(index: int, item_id: String, data: ItemData, equipped_slot: String) -> bool:
	var target: String = Inventory.default_slot_for(data)
	if equipped_slot == target:
		AudioManager.play_sfx(&"sfx_slot_equip") # already equipped: feedback only
		return true
	if Inventory.WEAPON_SLOTS.has(equipped_slot):
		# Already in the other weapon slot: it just becomes the active one
		Inventory.set_active_weapon(equipped_slot)
		return true
	var previous: String = Inventory.get_equipped_id(target)
	if not Inventory.equip(item_id, target):
		return false
	# What was equipped takes this slot (it leaves another quick slot if it was already assigned)
	var other: int = _slots.find(previous) if not previous.is_empty() else -1
	if other != -1 and other != index:
		_slots[other] = ""
		slot_changed.emit(other, "")
	_slots[index] = previous
	slot_changed.emit(index, previous)
	return true

func _on_inventory_changed() -> void:
	# Refreshes the HUD (amounts). A depleted consumable leaves its slot empty; equipment stays.
	for i: int in SLOT_COUNT:
		if _is_depleted_consumable(_slots[i]):
			_slots[i] = ""
		slot_changed.emit(i, _slots[i])

func _is_depleted_consumable(item_id: String) -> bool:
	if item_id.is_empty():
		return false
	var data: ItemData = ItemDatabase.get_item(item_id)
	return data != null and not data.is_equippable() and Inventory.get_owned_count(item_id) <= 0

# --- Persistence (backward compatible: a save without "quick_slots" leaves the slots empty) ---

static func create_snapshot() -> Array:
	return _slots.duplicate()

static func restore_snapshot(snapshot: Array) -> void:
	for i: int in SLOT_COUNT:
		_slots[i] = str(snapshot[i]) if i < snapshot.size() else ""
	if instance != null:
		is_restoring = true
		for i: int in SLOT_COUNT:
			instance.slot_changed.emit(i, _slots[i])
		is_restoring = false
