extends CanvasLayer

@onready var control: Control = $Control
@onready var item_list: ItemList = $Control/Panel/ItemList


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

## With the inventory open, input is intercepted before the GUI: the focused ItemList would consume
## the D-pad (ui_up/ui_down), Tab (ui_focus_next) and the digits (incremental search).
## List navigation stays on arrows/WASD/stick; the D-pad and 1-4 assign slots.
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

## Only keys and gamepad buttons: the stick (InputEventJoypadMotion) still navigates the list.
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
	# If the scene is unloaded while the inventory is open (e.g. when loading a save), release its pause
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
	# Keeps the selected row when rebuilding (using/assigning/equipping refreshes the list).
	# Looked up by item: when equipping, the rows change order.
	var selected: PackedInt32Array = item_list.get_selected_items()
	var previous_index: int = selected[0] if not selected.is_empty() else 0
	var previous_meta: Variant = item_list.get_item_metadata(previous_index) if not selected.is_empty() else null
	var previous_item_id: String = previous_meta as String if previous_meta is String else ""
	item_list.clear()
	_update_equipment_label()
	_fill_list()
	if item_list.item_count > 0:
		var index: int = mini(previous_index, item_list.item_count - 1)
		for i: int in item_list.item_count:
			if not previous_item_id.is_empty() and item_list.get_item_metadata(i) == previous_item_id:
				index = i
				break
		item_list.select(index)
		item_list.ensure_current_is_visible()

func _fill_list() -> void:
	var items: Dictionary = Inventory.get_items()
	if items.is_empty():
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

## Focus the list with the first row active: allows navigating without clicking first.
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
	var data: ItemData = ItemDatabase.get_item(id)
	if data and data.is_equippable():
		var slot: String = Inventory.default_slot_for(data)
		if Inventory.equip(id, slot):
			_show_notice("Equipado: %s" % data.name)
		return
	Inventory.use_item(id)

## Assigns the selected item to the quick slot (weapon, shield or consumable only).
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

## Fixed line below the title with the 3 equipment slots (placeholder until the HUD design).
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
	# Equipped items don't take up space in the list: they are only shown here
	var weapon: ItemData = Inventory.get_active_weapon()
	var shield: ItemData = Inventory.get_equipped(Inventory.SLOT_SHIELD)
	_equipment_label.text = "Arma: %s · Escudo: %s" % [weapon.name if weapon else "—", shield.name if shield else "—"]

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
