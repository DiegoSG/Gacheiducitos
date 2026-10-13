extends CanvasLayer

@onready var control: Control = $Control
@onready var item_list: ItemList = $Control/Panel/ItemList

const SLOT_NAMES: Dictionary = {
	Inventory.SLOT_WEAPON_1: "Arma 1",
	Inventory.SLOT_WEAPON_2: "Arma 2",
	Inventory.SLOT_SHIELD: "Escudo",
}
## Metadata de las filas de equipo: el slot va con este prefijo para distinguirlas de los ítems.
const EQUIPPED_META_PREFIX: String = "equipped:"

var _notice_label: Label = null
var _equipment_label: Label = null
var _notice_tween: Tween = null
var _connected_slots: QuickSlots = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if control:
		control.visible = false
		
	Inventory.inventory_changed.connect(_on_inventory_changed)
	Inventory.equipment_changed.connect(_on_equipment_changed)
	Inventory.active_weapon_changed.connect(_on_active_weapon_changed)

	if item_list:
		item_list.item_activated.connect(_on_item_activated)
		item_list.item_selected.connect(_on_item_selected)
	
	_create_notice_label()
	_create_equipment_label()
	refresh_ui()

## Con el inventario abierto se intercepta antes que la GUI: la ItemList con foco consumiría
## la cruceta (ui_up/ui_down), Tab (ui_focus_next) y los dígitos (búsqueda incremental).
## La navegación de la lista queda en flechas/WASD/stick; la cruceta y 1-4 asignan slots.
func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("toggle_inventory") or event.is_action_pressed("ui_cancel"):
		close_inventory()
		get_viewport().set_input_as_handled()
		return
	for i: int in QuickSlots.SLOT_COUNT:
		if _is_slot_assign_event(event, "slot_%d" % (i + 1)):
			_assign_selected_to_slot(i)
			get_viewport().set_input_as_handled()
			return

func _unhandled_input(event: InputEvent) -> void:
	if not is_open() and event.is_action_pressed("toggle_inventory"):
		open_inventory()
		get_viewport().set_input_as_handled()

## Solo teclas y botones del mando: el stick (InputEventJoypadMotion) sigue navegando la lista.
func _is_slot_assign_event(event: InputEvent, action: String) -> bool:
	if not (event is InputEventKey or event is InputEventJoypadButton):
		return false
	return event.is_action_pressed(action)

func toggle_inventory() -> void:
	if not control:
		return
	if control.visible:
		close_inventory()
	else:
		open_inventory()

func open_inventory() -> void:
	if control:
		_connect_quick_slots()
		control.visible = true
		AudioManager.play_ui(&"sfx_inventory_open")
		GameManager.request_pause()
		refresh_ui()
		_focus_list()

func close_inventory() -> void:
	if control and control.visible:
		if item_list:
			item_list.release_focus()
		control.visible = false
		AudioManager.play_ui(&"sfx_inventory_close")
		GameManager.release_pause()

func _exit_tree() -> void:
	# Si la escena se descarga con el inventario abierto (p. ej. al cargar partida), liberar su pausa
	if is_open():
		control.visible = false
		GameManager.release_pause()

func is_open() -> bool:
	return control.visible if control else false

func _on_inventory_changed() -> void:
	if is_open():
		refresh_ui()

func _on_equipment_changed(_slot: String, _item_id: String) -> void:
	_on_inventory_changed()

func _on_active_weapon_changed(_slot: String) -> void:
	_on_inventory_changed()

func refresh_ui() -> void:
	if not item_list:
		return
	# Conserva la fila seleccionada al reconstruir (usar/asignar/equipar refresca la lista).
	# Se busca por ítem: al equipar, las filas cambian de orden.
	var selected: PackedInt32Array = item_list.get_selected_items()
	var previous_index: int = selected[0] if not selected.is_empty() else 0
	var previous_meta: Variant = item_list.get_item_metadata(previous_index) if not selected.is_empty() else null
	var previous_item_id: String = _meta_item_id(previous_meta)
	item_list.clear()
	_update_equipment_label()
	_fill_equipped()
	_fill_list()
	if item_list.item_count > 0:
		var index: int = mini(previous_index, item_list.item_count - 1)
		for i: int in item_list.item_count:
			if not previous_item_id.is_empty() and _meta_item_id(item_list.get_item_metadata(i)) == previous_item_id:
				index = i
				break
		item_list.select(index)
		item_list.ensure_current_is_visible()

## Id del ítem de una fila (las filas de equipo guardan "equipped:<slot>").
func _meta_item_id(meta: Variant) -> String:
	if not meta is String:
		return ""
	var text: String = meta as String
	if text.begins_with(EQUIPPED_META_PREFIX):
		return Inventory.get_equipped_id(text.substr(EQUIPPED_META_PREFIX.length()))
	return text

## Filas del equipo puesto (arriba de la lista). Activarlas desequipa.
func _fill_equipped() -> void:
	for slot: String in Inventory.equipped:
		var data: ItemData = Inventory.get_equipped(slot)
		if data == null:
			continue
		var active_mark: String = " ★" if slot == Inventory.active_weapon else ""
		var idx: int = item_list.add_item("%s [%s%s]" % [data.name, SLOT_NAMES[slot], active_mark], data.icon)
		item_list.set_item_metadata(idx, EQUIPPED_META_PREFIX + slot)

func _fill_list() -> void:
	var items: Dictionary = Inventory.get_items()
	if items.is_empty():
		if item_list.item_count > 0:
			return
		item_list.add_item("(Inventario vacío)")
		return
		
	for item_id: String in items:
		var amount: int = items[item_id]
		var data: ItemData = ItemDatabase.get_item(item_id)
		var idx: int = -1
		var slot_tag: String = ""
		var slots: QuickSlots = QuickSlots.instance
		if slots and slots.find_slot(item_id) != -1:
			slot_tag = " [%d]" % (slots.find_slot(item_id) + 1)
		
		if data:
			idx = item_list.add_item("%s (x%d)%s" % [data.name, amount, slot_tag], data.icon)
		else:
			idx = item_list.add_item("%s (x%d)%s" % [item_id, amount, slot_tag])
			
		item_list.set_item_metadata(idx, item_id)

## Foco en la lista con la primera fila activa: permite navegar sin hacer clic antes.
func _focus_list() -> void:
	if not item_list:
		return
	item_list.grab_focus()
	if item_list.item_count > 0 and item_list.get_selected_items().is_empty():
		item_list.select(0)
		item_list.ensure_current_is_visible()

func _on_item_selected(_index: int) -> void:
	AudioManager.play_ui(&"sfx_inventory_move")

func _on_item_activated(index: int) -> void:
	if not item_list:
		return
	var item_id: Variant = item_list.get_item_metadata(index)
	if not item_id is String or (item_id as String).is_empty():
		return
	var id: String = item_id as String
	if id.begins_with(EQUIPPED_META_PREFIX):
		var slot: String = id.substr(EQUIPPED_META_PREFIX.length())
		Inventory.unequip(slot)
		_show_notice("%s: vacío" % SLOT_NAMES.get(slot, slot))
		return
	var data: ItemData = ItemDatabase.get_item(id)
	if data and data.is_equippable():
		var slot: String = Inventory.default_slot_for(data)
		if Inventory.equip(id, slot):
			_show_notice("Equipado en %s" % SLOT_NAMES.get(slot, slot))
		return
	Inventory.use_item(id)

## Asigna el ítem seleccionado al slot rápido (solo arma, escudo o consumible).
func _assign_selected_to_slot(slot_index: int) -> void:
	var slots: QuickSlots = QuickSlots.instance
	if not item_list or slots == null:
		return
	var selected: PackedInt32Array = item_list.get_selected_items()
	if selected.is_empty():
		_show_notice("Selecciona un ítem primero")
		return
	var item_id: Variant = item_list.get_item_metadata(selected[0])
	if not item_id is String or (item_id as String).is_empty():
		return
	if (item_id as String).begins_with(EQUIPPED_META_PREFIX):
		item_id = Inventory.get_equipped_id((item_id as String).substr(EQUIPPED_META_PREFIX.length()))
	if not QuickSlots.can_assign(item_id as String):
		AudioManager.play_ui(&"sfx_inventory_assign_fail")
		_show_notice("Este ítem no se puede asignar a un slot")
		return
	if slots.assign(slot_index, item_id as String):
		AudioManager.play_ui(&"sfx_inventory_assign")
		_show_notice("Asignado al slot %d" % (slot_index + 1))
		refresh_ui()

func _connect_quick_slots() -> void:
	var slots: QuickSlots = QuickSlots.instance
	if slots == _connected_slots or slots == null:
		return
	_connected_slots = slots
	slots.slot_changed.connect(func(_i: int, _id: String) -> void:
		if is_open():
			refresh_ui()
	)

func _create_notice_label() -> void:
	var panel: Control = get_node_or_null("Control/Panel") as Control
	if panel == null:
		return
	_notice_label = Label.new()
	_notice_label.anchor_top = 1.0
	_notice_label.anchor_bottom = 1.0
	_notice_label.anchor_right = 1.0
	_notice_label.offset_top = -26.0
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_label.modulate.a = 0.0
	_notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_notice_label)

## Línea fija bajo el título con los 3 slots de equipo (placeholder hasta el diseño del HUD).
func _create_equipment_label() -> void:
	var panel: Control = get_node_or_null("Control/Panel") as Control
	if panel == null or item_list == null:
		return
	_equipment_label = Label.new()
	_equipment_label.anchor_right = 1.0
	_equipment_label.offset_top = 26.0
	_equipment_label.offset_bottom = 70.0
	_equipment_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_equipment_label.add_theme_font_size_override("font_size", 12)
	_equipment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_equipment_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_equipment_label)
	item_list.offset_top = 74.0

func _update_equipment_label() -> void:
	if _equipment_label == null:
		return
	var parts: PackedStringArray = []
	for slot: String in Inventory.equipped:
		var data: ItemData = Inventory.get_equipped(slot)
		var active_mark: String = "★" if slot == Inventory.active_weapon else ""
		parts.append("%s%s: %s" % [active_mark, SLOT_NAMES[slot], data.name if data else "—"])
	_equipment_label.text = " · ".join(parts)

func _show_notice(text: String) -> void:
	if _notice_label == null:
		return
	_notice_label.text = text
	AudioManager.play_ui(&"sfx_inventory_notice")
	_notice_label.modulate.a = 1.0
	if _notice_tween:
		_notice_tween.kill()
	_notice_tween = create_tween()
	_notice_tween.tween_interval(1.2)
	_notice_tween.tween_property(_notice_label, "modulate:a", 0.0, 0.4)
