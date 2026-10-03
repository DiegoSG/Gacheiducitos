extends CanvasLayer

@onready var control: Control = $Control
@onready var item_list: ItemList = $Control/Panel/ItemList

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

## Se procesa en _input (antes que la GUI) para que Tab, los slots y ui_cancel
## no sean consumidos por el foco de la lista (Tab es también ui_focus_next).
## Con el inventario abierto, las flechas del D-Pad asignan slots; para navegar
## la lista se usan el stick izquierdo o las flechas/WASD del teclado.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		if not is_open() and get_tree().paused:
			return
		toggle_inventory()
		get_viewport().set_input_as_handled()
		return
	if not is_open():
		return
	if event.is_action_pressed("ui_cancel"):
		close_inventory()
		get_viewport().set_input_as_handled()
		return
	for i: int in QuickSlots.SLOT_COUNT:
		if event.is_action_pressed("slot_%d" % (i + 1)):
			_assign_selected_to_slot(i)
			get_viewport().set_input_as_handled()
			return

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
		if item_list:
			_focus_list.call_deferred()

func _focus_list() -> void:
	if item_list and is_open():
		item_list.grab_focus()
		if item_list.item_count > 0 and item_list.get_selected_items().is_empty():
			item_list.select(0)

func close_inventory() -> void:
	if control and control.visible:
		control.visible = false
		if item_list:
			item_list.release_focus()
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
	var previous: PackedInt32Array = item_list.get_selected_items()
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

	# Conserva la selección (o selecciona el primero) para poder navegar con mando/teclado.
	var keep: int = previous[0] if not previous.is_empty() else 0
	item_list.select(clampi(keep, 0, item_list.item_count - 1))

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
