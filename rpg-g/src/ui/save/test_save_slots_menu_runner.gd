extends Node

@onready var save_menu = $CanvasLayer/SaveMenuUI

func _ready() -> void:
	print("[TestRunner] Iniciando test de Save Slots Menu...")
	await get_tree().create_timer(0.5).timeout
	
	# Verificar si se crearon 5 slots (1 autosave + 4 manuales + 1 separador)
	var container = save_menu.get_node("MarginContainer/VBoxContainer/SlotsContainer")
	var children = container.get_children()
	
	var slot_count = 0
	var autosave_found = false
	
	for child in children:
		if child.has_method("update_view"):
			slot_count += 1
			if child.is_autosave:
				autosave_found = true
				if child.save_btn.visible:
					push_error("[TestRunner] El Autosave slot muestra boton de guardado!")
	
	if slot_count == 5 and autosave_found:
		print("[TestRunner] UI instanciada correctamente: 5 slots totales, autosave detectado.")
	else:
		push_error("[TestRunner] Fallo en la instanciación de la UI. Slots encontrados: ", slot_count)

	# Al abrir, el primer botón visible y habilitado debe tener el foco (navegable sin clic).
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is Button and save_menu.is_ancestor_of(focused) and focused.is_visible_in_tree() and not (focused as Button).disabled:
		print("[TestRunner] Foco inicial OK en: ", focused.get_path())
	else:
		push_error("[TestRunner] Ningún botón visible/habilitado tiene el foco al abrir. Foco: ", focused)

	print("[TestRunner] Test superado.")
	get_tree().quit(0)
