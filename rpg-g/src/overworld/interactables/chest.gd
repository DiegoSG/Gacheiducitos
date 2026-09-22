extends Actionable

@export_group("Loot & Storage")
@export var loot_items: Array[ItemData] = []
@export var is_storage_enabled: bool = false
@export var persistence_id: String = ""

@export_group("Visuals")
@export var texture_closed: Texture2D = preload("res://assets/sprites/chest_closed.png")
@export var texture_open: Texture2D = preload("res://assets/sprites/chest_open.png")

var is_open: bool = false
var has_been_looted: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var chest_dialogue: Resource = preload("res://src/overworld/interactables/chest.dialogue")

func _ready() -> void:
	if sprite:
		sprite.texture = texture_open if is_open else texture_closed
		sprite.modulate = Color.WHITE
	_restore_state()

func _restore_state() -> void:
	if persistence_id.is_empty():
		return
	var wsm := WorldStateManager
	if not wsm or not wsm.has_state(persistence_id):
		return
	var data: Dictionary = wsm.load_state(persistence_id)
	has_been_looted = data.get("has_been_looted", false)
	is_open = data.get("is_open", false)
	if sprite:
		sprite.texture = texture_open if is_open else texture_closed

func action() -> void:
	if not is_open:
		open_chest()
	else:
		close_chest()

func open_chest() -> void:
	is_open = true
	if sprite:
		sprite.texture = texture_open
		sprite.modulate = Color.WHITE
	print("Chest ", persistence_id, " opened.")

	if not has_been_looted:
		give_loot()
	else:
		show_message("empty")

	if is_storage_enabled:
		open_storage()
	_persist_state()

func close_chest() -> void:
	is_open = false
	if sprite:
		sprite.texture = texture_closed
		sprite.modulate = Color.WHITE
	print("Chest ", persistence_id, " closed.")
	show_message("closed")
	_persist_state()

func give_loot() -> void:
	if loot_items.is_empty():
		show_message("empty")
		has_been_looted = true
		_persist_state()
		return

	for item in loot_items:
		if item:
			if item.id == "gold_coins":
				PlayerStats.add_gold(item.value)
				LootFeedbackManager.trigger_loot_pickup(item, global_position, item.value)
			else:
				Inventory.add_item(item.id, 1)
				LootFeedbackManager.trigger_loot_pickup(item, global_position, 1)

	has_been_looted = true
	_persist_state()

func show_message(title: String) -> void:
	if Engine.has_singleton("DialogueManager"):
		var dialogue_manager = Engine.get_singleton("DialogueManager")
		dialogue_manager.show_dialogue_balloon(chest_dialogue, title)
	else:
		print("DIÁLOGO: ", title)

func open_storage() -> void:
	print("Opening storage UI (Not implemented yet)...")

func _persist_state() -> void:
	if persistence_id.is_empty():
		return
	var wsm := WorldStateManager
	if wsm:
		wsm.save_state(persistence_id, {"has_been_looted": has_been_looted, "is_open": is_open})
