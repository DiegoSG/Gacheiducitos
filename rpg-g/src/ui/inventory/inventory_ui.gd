extends CanvasLayer

@onready var control: Control = $Control
@onready var item_list: ItemList = $Control/Panel/ItemList
@onready var save_menu: Panel = $Control/SaveMenuUI

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if control:
		control.visible = false
		
	Inventory.inventory_changed.connect(_on_inventory_changed)

	if item_list:
		item_list.item_activated.connect(_on_item_activated)
	
	refresh_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
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
		
		if data:
			idx = item_list.add_item("%s (x%d)" % [data.name, amount], data.icon)
		else:
			idx = item_list.add_item("%s (x%d)" % [item_id, amount])
			
		item_list.set_item_metadata(idx, item_id)

func _on_item_activated(index: int) -> void:
	if not item_list:
		return
	var item_id: Variant = item_list.get_item_metadata(index)
	if item_id is String and not (item_id as String).is_empty():
		Inventory.use_item(item_id as String)
