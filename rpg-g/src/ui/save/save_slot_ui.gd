extends PanelContainer

signal save_requested(slot_id: int)
signal load_requested(slot_id: int)

@export var slot_id: int = 1
@export var is_autosave: bool = false

@onready var title_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/TitleLabel
@onready var details_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/DetailsLabel
@onready var save_btn: Button = $MarginContainer/HBoxContainer/ActionsContainer/SaveBtn
@onready var load_btn: Button = $MarginContainer/HBoxContainer/ActionsContainer/LoadBtn

func _ready() -> void:
	if save_btn:
		save_btn.pressed.connect(func(): save_requested.emit(slot_id))
	if load_btn:
		load_btn.pressed.connect(func(): load_requested.emit(slot_id))
	
	if is_autosave and save_btn:
		save_btn.hide() # We cannot manually save over the autosave slot

func setup(id: int, auto: bool) -> void:
	slot_id = id
	is_autosave = auto
	if is_autosave and save_btn:
		save_btn.hide()

func update_view(metadata: Dictionary) -> void:
	if not title_label or not details_label:
		return
		
	if is_autosave:
		title_label.text = "Autoguardado"
	else:
		title_label.text = "Slot " + str(slot_id)
		
	if metadata.get("exists", false):
		var time_str: String = Time.get_datetime_string_from_unix_time(metadata.get("timestamp", 0.0), true)
		time_str = time_str.replace("T", " ")
		
		var lvl: String = metadata.get("level_name", "???")
		var hp: int = metadata.get("health", 0)
		var max_hp: int = metadata.get("max_health", 0)
		var gold: int = metadata.get("gold", 0)
		
		details_label.text = "%s | %s\nHP: %d/%d | 🪙 %d" % [lvl, time_str, hp, max_hp, gold]
		
		if load_btn:
			load_btn.disabled = false
	else:
		details_label.text = "[Ranura Vacía]"
		if load_btn:
			load_btn.disabled = true
