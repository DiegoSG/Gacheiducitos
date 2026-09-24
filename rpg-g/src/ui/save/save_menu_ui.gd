extends Panel

const SaveSlotUI = preload("res://src/ui/save/save_slot_ui.tscn")

@onready var slots_container: VBoxContainer = $MarginContainer/VBoxContainer/SlotsContainer

func _ready() -> void:
	var ss = get_node_or_null("/root/SaveSystem")
	if ss:
		if not ss.game_saved.is_connected(_on_game_saved):
			ss.game_saved.connect(_on_game_saved)
		if not ss.game_loaded.is_connected(_on_game_loaded):
			ss.game_loaded.connect(_on_game_loaded)
		if ss.has_signal("game_deleted") and not ss.game_deleted.is_connected(_on_game_deleted):
			ss.game_deleted.connect(_on_game_deleted)
	
	_build_slots()
	refresh()

func _build_slots() -> void:
	for child in slots_container.get_children():
		child.queue_free()
		
	var ss = get_node_or_null("/root/SaveSystem")
	if not ss: return
	
	# Autosave slot first (ID 0)
	var autosave_slot = SaveSlotUI.instantiate()
	slots_container.add_child(autosave_slot)
	autosave_slot.setup(ss.AUTOSAVE_SLOT_ID, true)
	autosave_slot.save_requested.connect(_on_slot_save_requested)
	autosave_slot.load_requested.connect(_on_slot_load_requested)
	autosave_slot.delete_requested.connect(_on_slot_delete_requested)
	
	var separator = HSeparator.new()
	slots_container.add_child(separator)
	
	# Manual slots (IDs 1 to MAX)
	var max_slots = ss.MAX_MANUAL_SLOTS if "MAX_MANUAL_SLOTS" in ss else 4
	for i in range(1, max_slots + 1):
		var slot = SaveSlotUI.instantiate()
		slots_container.add_child(slot)
		slot.setup(i, false)
		slot.save_requested.connect(_on_slot_save_requested)
		slot.load_requested.connect(_on_slot_load_requested)
		slot.delete_requested.connect(_on_slot_delete_requested)

func refresh() -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		return
		
	var ss = get_node_or_null("/root/SaveSystem")
	if not ss: return
	
	var metadatas: Array = ss.get_all_slots_metadata()
	for child in slots_container.get_children():
		if child is Control and child.has_method("update_view"):
			var slot_id: int = child.slot_id
			if slot_id >= 0 and slot_id < metadatas.size():
				child.update_view(metadatas[slot_id])

func _on_slot_save_requested(slot_id: int) -> void:
	var ss = get_node_or_null("/root/SaveSystem")
	if ss:
		ss.save_slot(slot_id)

func _on_slot_load_requested(slot_id: int) -> void:
	var ss = get_node_or_null("/root/SaveSystem")
	if ss:
		ss.load_slot(slot_id)

func _on_slot_delete_requested(slot_id: int) -> void:
	var ss = get_node_or_null("/root/SaveSystem")
	if ss and ss.has_method("delete_slot"):
		ss.delete_slot(slot_id)

func _on_game_saved(slot_id: int) -> void:
	refresh()
	
func _on_game_loaded(slot_id: int) -> void:
	refresh()

func _on_game_deleted(slot_id: int) -> void:
	refresh()
