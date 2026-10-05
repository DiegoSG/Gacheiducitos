extends Node
class_name QuickSlots

## Componente de slots rápidos (PLACEHOLDER funcional): 4 casillas que guardan un item_id.
## Consumible: se consume vía Inventory.use_item. Arma/escudo: solo emite equip_requested
## (el efecto real de equipar se implementará después).

signal slot_changed(index: int, item_id: String)
signal slot_used(index: int, item_id: String)
signal equip_requested(index: int, item_id: String)

const SLOT_COUNT: int = 4

## Instancia activa (la del Player del nivel actual); HUD e inventario la consultan.
static var instance: QuickSlots = null
## Los datos viven fuera del nodo para sobrevivir al cambio de nivel (el Player se reinstancia).
static var _slots: Array[String] = ["", "", "", ""]
## true mientras restore_snapshot reemite slot_changed (al cargar partida), para no sonar.
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

## Solo armas, escudos y consumibles pueden asignarse (llaves, quest y materiales no).
static func can_assign(item_id: String) -> bool:
	var data: ItemData = ItemDatabase.get_item(item_id)
	if data == null:
		return false
	if data.type == ItemData.ItemType.CONSUMABLE:
		return data.consumable
	if data.type == ItemData.ItemType.EQUIPMENT:
		return data.equip_kind != ItemData.EquipKind.NONE
	return false

func get_slot(index: int) -> String:
	if index < 0 or index >= SLOT_COUNT:
		return ""
	return _slots[index]

## Slot que contiene el ítem, o -1.
func find_slot(item_id: String) -> int:
	return _slots.find(item_id)

## Asigna el ítem al slot (un ítem ocupa un solo slot). Devuelve false si no es asignable.
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
	if data == null or Inventory.get_item_count(item_id) <= 0:
		AudioManager.play_sfx(&"sfx_slot_empty")
		return false
	if data.type == ItemData.ItemType.CONSUMABLE:
		if not Inventory.use_item(item_id):
			return false
		AudioManager.play_sfx(&"sfx_slot_use")
	elif data.type == ItemData.ItemType.EQUIPMENT:
		AudioManager.play_sfx(&"sfx_slot_equip")
		print("[QuickSlots] Equipar solicitado (placeholder): slot %d -> %s" % [index + 1, item_id])
		equip_requested.emit(index, item_id)
	else:
		return false
	slot_used.emit(index, item_id)
	return true

func _on_inventory_changed() -> void:
	# Refresca el HUD (cantidades); los ítems agotados siguen asignados.
	for i: int in SLOT_COUNT:
		slot_changed.emit(i, _slots[i])

# --- Persistencia (retrocompatible: un save sin "quick_slots" deja los slots vacíos) ---

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
