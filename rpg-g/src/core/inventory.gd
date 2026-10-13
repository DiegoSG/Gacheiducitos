extends Node

signal inventory_changed
## Cambió lo que hay en un slot de equipo ("" = vacío).
signal equipment_changed(slot: String, item_id: String)
## Cambió cuál de los dos slots de arma está activo.
signal active_weapon_changed(slot: String)

## Id del "objeto" oro. El oro vive SOLO en PlayerStats.gold; este id se enruta allí
## y nunca se guarda en `items`.
const GOLD_ITEM_ID: String = "gold_coins"

const SLOT_WEAPON_1: String = "weapon_1"
const SLOT_WEAPON_2: String = "weapon_2"
const SLOT_SHIELD: String = "shield"
const WEAPON_SLOTS: Array[String] = [SLOT_WEAPON_1, SLOT_WEAPON_2]

# Dictionary to store items: {"item_id": amount}
var items: Dictionary = {}

## Slots de equipo: {slot: item_id}. Un arma cuerpo a cuerpo o un escudo equipado sale de `items`
## y vuelve al desequiparlo; una arrojadiza se queda en `items` (su cantidad es la munición).
var equipped: Dictionary = {SLOT_WEAPON_1: "", SLOT_WEAPON_2: "", SLOT_SHIELD: ""}
var active_weapon: String = SLOT_WEAPON_1

func add_item(item_id: String, amount: int = 1) -> void:
	if item_id.is_empty() or amount <= 0:
		return

	if item_id == GOLD_ITEM_ID:
		PlayerStats.add_gold(amount)
		AudioManager.play_ui(&"sfx_inventory_gold")
		return

	items[item_id] = int(items.get(item_id, 0)) + amount
	AudioManager.play_ui(&"sfx_inventory_changed")
	inventory_changed.emit()

## Atómico: si no hay cantidad suficiente devuelve false y no quita nada.
func remove_item(item_id: String, amount: int = 1) -> bool:
	if item_id.is_empty() or amount <= 0:
		return false

	if item_id == GOLD_ITEM_ID:
		return PlayerStats.remove_gold(amount)

	if get_owned_count(item_id) < amount:
		return false
	# Si solo alcanza contando lo equipado (p. ej. entregar la espada que llevas), se desequipa primero
	if get_item_count(item_id) < amount:
		unequip(find_equipped_slot(item_id))

	var remaining: int = int(items[item_id]) - amount
	if remaining <= 0:
		items.erase(item_id)
	else:
		items[item_id] = remaining

	AudioManager.play_ui(&"sfx_inventory_changed")
	inventory_changed.emit()
	return true

## Usa un consumible: aplica cada efecto y consume 1 unidad. Devuelve false si no es consumible o no tiene efectos.
func use_item(item_id: String) -> bool:
	if get_item_count(item_id) <= 0:
		return false

	var data: ItemData = ItemDatabase.get_item(item_id)
	if not data or not data.consumable or data.effects.is_empty():
		AudioManager.play_ui(&"sfx_inventory_use_fail")
		return false

	for effect: ItemEffect in data.effects:
		if effect:
			effect.apply()

	AudioManager.play_ui(&"sfx_inventory_use")
	remove_item(item_id, 1)
	return true

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
	return get_owned_count(item_id) >= amount

# --- Equipamiento (ver design/Sistema_Armas_y_Escudo.md) ---------------------

## true si el ítem puede ir en ese slot según el `kind` de su equipo.
static func slot_accepts(slot: String, data: ItemData) -> bool:
	if data == null or data.equipment == null:
		return false
	if slot == SLOT_SHIELD:
		return data.equipment is ShieldData
	if WEAPON_SLOTS.has(slot):
		return data.equipment.is_weapon() and not data.equipment is ShieldData
	return false

## Slot por defecto para equipar un ítem: el escudo en el suyo; un arma en el slot activo.
func default_slot_for(data: ItemData) -> String:
	if data == null or data.equipment == null:
		return ""
	return SLOT_SHIELD if data.equipment.kind == EquipmentData.Kind.SHIELD else active_weapon

## Equipa el ítem en el slot. Lo que ocupaba el slot vuelve al inventario; si el ítem ya estaba
## en el otro slot de arma, los dos se intercambian.
func equip(item_id: String, slot: String) -> bool:
	if not equipped.has(slot):
		return false
	var data: ItemData = ItemDatabase.get_item(item_id)
	if not slot_accepts(slot, data):
		AudioManager.play_ui(&"sfx_inventory_assign_fail")
		return false
	if equipped[slot] == item_id:
		return true
	var other: String = find_equipped_slot(item_id)
	if other != "":
		var previous_in_slot: String = equipped[slot]
		equipped[slot] = item_id
		equipped[other] = previous_in_slot
		AudioManager.play_ui(&"sfx_slot_equip")
		equipment_changed.emit(other, previous_in_slot)
		equipment_changed.emit(slot, item_id)
		return true
	if get_item_count(item_id) <= 0:
		return false
	var previous: String = equipped[slot]
	if _leaves_inventory(data):
		_change_count(item_id, -1)
	if previous != "" and _leaves_inventory(ItemDatabase.get_item(previous)):
		_change_count(previous, 1)
	equipped[slot] = item_id
	AudioManager.play_ui(&"sfx_slot_equip")
	inventory_changed.emit()
	equipment_changed.emit(slot, item_id)
	return true

## Vacía el slot y devuelve su ítem al inventario.
func unequip(slot: String) -> void:
	if not equipped.has(slot) or String(equipped[slot]).is_empty():
		return
	var item_id: String = equipped[slot]
	equipped[slot] = ""
	if _leaves_inventory(ItemDatabase.get_item(item_id)):
		_change_count(item_id, 1)
	AudioManager.play_ui(&"sfx_slot_clear")
	inventory_changed.emit()
	equipment_changed.emit(slot, "")

## Alterna el arma activa entre los dos slots (aunque el otro esté vacío: golpe base).
func switch_active_weapon() -> void:
	set_active_weapon(SLOT_WEAPON_2 if active_weapon == SLOT_WEAPON_1 else SLOT_WEAPON_1)

func set_active_weapon(slot: String) -> void:
	if not WEAPON_SLOTS.has(slot) or slot == active_weapon:
		return
	active_weapon = slot
	AudioManager.play_sfx(&"sfx_player_weapon_switch")
	active_weapon_changed.emit(slot)

func get_equipped_id(slot: String) -> String:
	return String(equipped.get(slot, ""))

func get_equipped(slot: String) -> ItemData:
	var item_id: String = get_equipped_id(slot)
	return null if item_id.is_empty() else ItemDatabase.get_item(item_id)

func get_active_weapon() -> ItemData:
	return get_equipped(active_weapon)

## Arma cuerpo a cuerpo activa, o null (slot vacío o arrojadiza).
func get_active_melee() -> WeaponData:
	var data: ItemData = get_active_weapon()
	if data == null or data.equipment.kind != EquipmentData.Kind.MELEE:
		return null
	return data.equipment as WeaponData

func get_equipped_shield() -> ShieldData:
	var data: ItemData = get_equipped(SLOT_SHIELD)
	return data.equipment as ShieldData if data != null else null

## Slot donde está equipado el ítem, o "".
func find_equipped_slot(item_id: String) -> String:
	if item_id.is_empty():
		return ""
	for slot: String in equipped:
		if equipped[slot] == item_id:
			return slot
	return ""

## Unidades que tiene el jugador contando las equipadas (para condiciones "item.x").
func get_owned_count(item_id: String) -> int:
	var count: int = get_item_count(item_id)
	var slot: String = find_equipped_slot(item_id)
	if slot != "" and _leaves_inventory(ItemDatabase.get_item(item_id)):
		count += 1
	return count

func _leaves_inventory(data: ItemData) -> bool:
	return data == null or data.equipment == null or data.equipment.kind != EquipmentData.Kind.THROWABLE

## Suma o resta unidades sin sonido ni señal (las emite quien llama).
func _change_count(item_id: String, delta: int) -> void:
	var remaining: int = int(items.get(item_id, 0)) + delta
	if remaining <= 0:
		items.erase(item_id)
	else:
		items[item_id] = remaining

# --- Persistencia ----------------------------------------------------------

func create_snapshot() -> Dictionary:
	return {
		"items": items.duplicate(true),
		"equipped": equipped.duplicate(),
		"active_weapon": active_weapon
	}

## Acepta el formato nuevo y el antiguo (un diccionario plano {item_id: cantidad}, sin equipo).
func restore_snapshot(snapshot: Dictionary) -> void:
	var is_new_format: bool = snapshot.get("items") is Dictionary and snapshot.has("equipped")
	items = (snapshot["items"] as Dictionary).duplicate(true) if is_new_format else snapshot.duplicate(true)
	# Migración de saves antiguos: el oro se guardaba dentro de items; ahora vive solo en PlayerStats
	items.erase(GOLD_ITEM_ID)
	var saved_equipped: Dictionary = snapshot.get("equipped", {}) if is_new_format else {}
	for slot: String in equipped:
		var saved_id: String = str(saved_equipped.get(slot, ""))
		if not saved_id.is_empty() and not slot_accepts(slot, ItemDatabase.get_item(saved_id)):
			# Ítem borrado, renombrado o de una escena de prueba: el slot queda vacío
			push_warning("[Inventory] Equipo guardado no válido en %s: %s" % [slot, saved_id])
			saved_id = ""
		equipped[slot] = saved_id
	var saved_active: String = str(snapshot.get("active_weapon", SLOT_WEAPON_1))
	active_weapon = saved_active if WEAPON_SLOTS.has(saved_active) else SLOT_WEAPON_1
	inventory_changed.emit()
	for slot: String in equipped:
		equipment_changed.emit(slot, equipped[slot])
	active_weapon_changed.emit(active_weapon)
