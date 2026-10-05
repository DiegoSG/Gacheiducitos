extends Node

## Prueba aislada del inventario: sin menú de guardado, foco en la lista con la primera fila
## seleccionada al abrir, y la selección se conserva al refrescar.

@onready var inventory_ui: CanvasLayer = $InventoryUI

func _ready() -> void:
	print("[TestInventoryUI] Iniciando...")
	var ok: bool = true
	Inventory.restore_snapshot({})
	Inventory.add_item("test_item_a", 2)
	Inventory.add_item("test_item_b", 1)
	await get_tree().process_frame

	if inventory_ui.get_node_or_null("Control/SaveMenuUI") != null:
		push_error("[TestInventoryUI] El inventario aún contiene SaveMenuUI")
		ok = false

	inventory_ui.open_inventory()
	await get_tree().process_frame

	var item_list: ItemList = inventory_ui.get_node("Control/Panel/ItemList") as ItemList
	if get_viewport().gui_get_focus_owner() != item_list:
		push_error("[TestInventoryUI] La lista no tiene el foco al abrir")
		ok = false
	if item_list.get_selected_items() != PackedInt32Array([0]):
		push_error("[TestInventoryUI] La primera fila no está seleccionada al abrir")
		ok = false

	item_list.select(1)
	inventory_ui.refresh_ui()
	if item_list.get_selected_items() != PackedInt32Array([1]):
		push_error("[TestInventoryUI] Se perdió la selección al refrescar")
		ok = false

	inventory_ui.close_inventory()
	print("[TestInventoryUI] ", "Test superado." if ok else "Test FALLIDO.")
	get_tree().quit(0 if ok else 1)
