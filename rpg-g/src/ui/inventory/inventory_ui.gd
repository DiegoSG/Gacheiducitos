extends CanvasLayer

@onready var control: Control = $Control
@onready var item_list: ItemList = $Control/Panel/ItemList

func _ready() -> void:
	# El inventario inicia cerrado
	if control:
		control.visible = false
		
	# Conexión al inventario global para actualizar reactivamente
	if Inventory:
		Inventory.inventory_changed.connect(_on_inventory_changed)
	
	refresh_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_TAB or (InputMap.has_action("toggle_inventory") and event.is_action_pressed("toggle_inventory")):
			toggle_inventory()
			get_viewport().set_input_as_handled()

func toggle_inventory() -> void:
	if not control:
		return
	control.visible = !control.visible
	if control.visible:
		refresh_ui()

func open_inventory() -> void:
	if control:
		control.visible = true
		refresh_ui()

func close_inventory() -> void:
	if control:
		control.visible = false

func is_open() -> bool:
	return control.visible if control else false

func _on_inventory_changed() -> void:
	if is_open():
		refresh_ui()

func refresh_ui() -> void:
	if not item_list:
		return
	item_list.clear()
	
	if not Inventory or not ItemDatabase:
		return
		
	var items: Dictionary = Inventory.get_items()
	if items.is_empty():
		item_list.add_item("(Inventario vacío)")
		return
		
	for item_id in items:
		var amount: int = items[item_id]
		var data: ItemData = ItemDatabase.get_item(item_id)
		
		if data:
			item_list.add_item("%s (x%d)" % [data.name, amount], data.icon)
		else:
			item_list.add_item("%s (x%d)" % [item_id, amount])
