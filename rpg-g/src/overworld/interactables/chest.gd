extends Actionable

@export_group("Loot & Storage")
@export var loot_items: Array[ItemData] = []
@export var is_storage_enabled: bool = false
@export var chest_id: String = "" # Unique ID for persistence if needed later

var is_open: bool = false
var has_been_looted: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var chest_dialogue: Resource = preload("res://src/overworld/interactables/chest.dialogue")

func action() -> void:
	if not is_open:
		open_chest()
	else:
		close_chest()

func open_chest() -> void:
	is_open = true
	# Visual feedback for open chest
	sprite.modulate = Color(1.0, 1.0, 1.0) # Original color or "active"
	# In a real game, you'd change the sprite to an open version here.
	print("Chest ", chest_id, " opened.")
	
	if not has_been_looted:
		give_loot()
	else:
		show_message("empty")
	
	if is_storage_enabled:
		open_storage()

func close_chest() -> void:
	is_open = false
	sprite.modulate = Color(0.6, 0.4, 0.2) # Back to "closed" brown
	print("Chest ", chest_id, " closed.")
	show_message("closed")

func give_loot() -> void:
	if loot_items.is_empty():
		show_message("empty")
		has_been_looted = true
		return
		
	var item_names = []
	for item in loot_items:
		if item:
			if item.id == "gold_coins":
				PlayerStats.add_gold(item.value)
				item_names.append(str(item.value) + " monedas de oro")
			else:
				Inventory.add_item(item.id, 1)
				item_names.append(item.name)
	
	var message = "Obtuviste:\n"
	for item_name in item_names:
		message += "- " + item_name + "\n"
	
	show_loot_dialogue(message.strip_edges())
	has_been_looted = true

func show_loot_dialogue(loot_message: String) -> void:
	if Engine.has_singleton("DialogueManager"):
		var dialogue_manager = Engine.get_singleton("DialogueManager")
		dialogue_manager.show_dialogue_balloon(chest_dialogue, "loot", [{"loot_message": loot_message}])
	else:
		print("Has encontrado: ", loot_message)

func show_message(title: String) -> void:
	if Engine.has_singleton("DialogueManager"):
		var dialogue_manager = Engine.get_singleton("DialogueManager")
		dialogue_manager.show_dialogue_balloon(chest_dialogue, title)
	else:
		print("DIÁLOGO: ", title)

func open_storage() -> void:
	print("Opening storage UI (Not implemented yet)...")
