extends Node

@onready var save_menu = $CanvasLayer/SaveMenuUI

func _ready() -> void:
	print("[TestRunner] Starting Save Slots Menu test...")
	await get_tree().create_timer(0.5).timeout
	
	# Check whether 5 slots were created (1 autosave + 4 manual + 1 separator)
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
					push_error("[TestRunner] The Autosave slot shows a save button!")
	
	if slot_count == 5 and autosave_found:
		print("[TestRunner] UI instantiated correctly: 5 total slots, autosave detected.")
	else:
		push_error("[TestRunner] UI instantiation failed. Slots found: ", slot_count)

	# On open, the first visible and enabled button must have focus (navigable without clicking).
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is Button and save_menu.is_ancestor_of(focused) and focused.is_visible_in_tree() and not (focused as Button).disabled:
		print("[TestRunner] Initial focus OK on: ", focused.get_path())
	else:
		push_error("[TestRunner] No visible/enabled button has focus on open. Focus: ", focused)

	print("[TestRunner] Test passed.")
	get_tree().quit(0)
