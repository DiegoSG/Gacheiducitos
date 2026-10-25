extends Panel

const SaveSlotUI: PackedScene = preload("res://src/ui/save/save_slot_ui.tscn")

@onready var slots_container: VBoxContainer = $MarginContainer/VBoxContainer/SlotsContainer

func _ready() -> void:
	if not SaveSystem.game_saved.is_connected(_on_game_saved):
		SaveSystem.game_saved.connect(_on_game_saved)
	if not SaveSystem.game_loaded.is_connected(_on_game_loaded):
		SaveSystem.game_loaded.connect(_on_game_loaded)
	if not SaveSystem.game_deleted.is_connected(_on_game_deleted):
		SaveSystem.game_deleted.connect(_on_game_deleted)

	_build_slots()
	refresh()

func _build_slots() -> void:
	for child: Node in slots_container.get_children():
		child.queue_free()

	# Autosave slot first (ID 0)
	var autosave_slot: Control = SaveSlotUI.instantiate()
	slots_container.add_child(autosave_slot)
	autosave_slot.setup(SaveSystem.AUTOSAVE_SLOT_ID, true)
	autosave_slot.save_requested.connect(_on_slot_save_requested)
	autosave_slot.load_requested.connect(_on_slot_load_requested)
	autosave_slot.delete_requested.connect(_on_slot_delete_requested)

	var separator: HSeparator = HSeparator.new()
	slots_container.add_child(separator)

	# Manual slots (IDs 1 to MAX)
	for i: int in range(1, SaveSystem.MAX_MANUAL_SLOTS + 1):
		var slot: Control = SaveSlotUI.instantiate()
		slots_container.add_child(slot)
		slot.setup(i, false)
		slot.save_requested.connect(_on_slot_save_requested)
		slot.load_requested.connect(_on_slot_load_requested)
		slot.delete_requested.connect(_on_slot_delete_requested)

func refresh() -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		return

	var metadatas: Array[Dictionary] = SaveSystem.get_all_slots_metadata()
	for child: Node in slots_container.get_children():
		if child is Control and child.has_method("update_view"):
			var slot_id: int = child.slot_id
			if slot_id >= 0 and slot_id < metadatas.size():
				child.update_view(metadatas[slot_id])
	_restore_focus_if_lost()

## Al borrar un slot su botón se oculta y el foco se pierde: lo devuelve al primer botón disponible.
func _restore_focus_if_lost() -> void:
	var owner_control: Control = get_viewport().gui_get_focus_owner()
	if owner_control != null and is_ancestor_of(owner_control) and owner_control.is_visible_in_tree():
		return
	if owner_control != null and not is_ancestor_of(owner_control):
		return # El foco está en otro menú; no se lo quitamos.
	focus_first()

## Da el foco al primer botón visible y habilitado de los slots.
func focus_first() -> void:
	for node: Node in slots_container.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if not button.disabled and button.is_visible_in_tree():
			button.grab_focus()
			return

func _on_slot_save_requested(slot_id: int) -> void:
	SaveSystem.save_slot(slot_id)

func _on_slot_load_requested(slot_id: int) -> void:
	SaveSystem.load_slot(slot_id)

func _on_slot_delete_requested(slot_id: int) -> void:
	SaveSystem.delete_slot(slot_id)

func _on_game_saved(_slot_id: int) -> void:
	refresh()

func _on_game_loaded(_slot_id: int) -> void:
	refresh()

func _on_game_deleted(_slot_id: int) -> void:
	refresh()
