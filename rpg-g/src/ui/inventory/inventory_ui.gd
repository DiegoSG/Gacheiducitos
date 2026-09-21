extends CanvasLayer

@onready var control: Control = $Control
@onready var item_list: ItemList = $Control/Panel/ItemList

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# El inventario inicia cerrado
	if control:
		control.visible = false
		
	# Conexión al inventario global para actualizar reactivamente
	var inv = get_node_or_null("/root/Inventory")
	if inv:
		inv.inventory_changed.connect(_on_inventory_changed)
	
	if item_list:
		item_list.item_activated.connect(_on_item_activated)
	
	refresh_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_TAB):
		toggle_inventory()
		get_viewport().set_input_as_handled()
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
		control.visible = true
		get_tree().paused = true
		refresh_ui()

func close_inventory() -> void:
	if control:
		control.visible = false
		get_tree().paused = false

func is_open() -> bool:
	return control.visible if control else false

func _on_inventory_changed() -> void:
	if is_open():
		refresh_ui()

func refresh_ui() -> void:
	if not item_list:
		return
	item_list.clear()
	
	var inv = get_node_or_null("/root/Inventory")
	var item_db = get_node_or_null("/root/ItemDatabase")
	if not inv or not item_db:
		return
		
	var items: Dictionary = inv.get_items()
	if items.is_empty():
		item_list.add_item("(Inventario vacío)")
		return
		
	for item_id in items:
		var amount: int = items[item_id]
		var data: ItemData = item_db.get_item(item_id)
		var idx: int = -1
		
		if data:
			idx = item_list.add_item("%s (x%d)" % [data.name, amount], data.icon)
		else:
			idx = item_list.add_item("%s (x%d)" % [item_id, amount])
			
		item_list.set_item_metadata(idx, item_id)

func _on_item_activated(index: int) -> void:
	if not item_list:
		return
	var item_id = item_list.get_item_metadata(index)
	if item_id and item_id is String:
		var inv = get_node_or_null("/root/Inventory")
		if inv:
			inv.use_item(item_id)
