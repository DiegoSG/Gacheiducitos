extends CanvasLayer

@onready var control: Control = $Control
@onready var item_list: ItemList = $Control/Panel/ItemList
@onready var save_menu: Panel = $Control/SaveMenuUI

var _notice_label: Label = null
var _notice_tween: Tween = null
var _connected_slots: QuickSlots = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if control:
		control.visible = false
		
	Inventory.inventory_changed.connect(_on_inventory_changed)

	if item_list:
		item_list.item_activated.connect(_on_item_activated)
	
	_create_notice_label()
	refresh_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		toggle_inventory()
		get_viewport().set_input_as_handled()
		return
	if is_open():
		for i: int in QuickSlots.SLOT_COUNT:
			if event.is_action_pressed("slot_%d" % (i + 1)):
				_assign_selected_to_slot(i)
				get_viewport().set_input_as_handled()
				return
	elif is_open() and event.is_action_pressed("ui_cancel"):
		close_inventory()
		get_viewport().set_input_as_handled()

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
		GameManager.request_pause()
		refresh_ui()
		if save_menu and save_menu.has_method("refresh"):
			save_menu.refresh()

func close_inventory() -> void:
	if control and control.visible:
		control.visible = false
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

func refresh_ui() -> void:
	if not item_list:
		return
	item_list.clear()
	
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

func _on_item_activated(index: int) -> void:
	if not item_list:
		return
	var item_id: Variant = item_list.get_item_metadata(index)
	if item_id is String and not (item_id as String).is_empty():
		Inventory.use_item(item_id as String)

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
	if not QuickSlots.can_assign(item_id as String):
		_show_notice("Este ítem no se puede asignar a un slot")
		return
	if slots.assign(slot_index, item_id as String):
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

func _show_notice(text: String) -> void:
	if _notice_label == null:
		return
	_notice_label.text = text
	_notice_label.modulate.a = 1.0
	if _notice_tween:
		_notice_tween.kill()
	_notice_tween = create_tween()
	_notice_tween.tween_interval(1.2)
	_notice_tween.tween_property(_notice_label, "modulate:a", 0.0, 0.4)
