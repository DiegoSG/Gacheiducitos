extends CanvasLayer

@onready var item_list: ItemList = $Control/Panel/ItemList

func _ready() -> void:
	# Check if our global inventory singleton exists
	var inventory = get_node_or_null("/root/Inventory")
	if inventory:
		# Connect to the signal to refresh when items change
		inventory.inventory_changed.connect(refresh_ui)
		# Initial populate
		refresh_ui()

func refresh_ui() -> void:
	if not item_list: return
	item_list.clear() # Clear old entries
	
	var inventory = get_node_or_null("/root/Inventory")
	var database = get_node_or_null("/root/ItemDatabase")
	
	if inventory and database:
		var items = inventory.get_items()
		for item_id in items:
			var amount = items[item_id]
			var data = database.get_item(item_id)
			
			if data:
				# Add with name and icon from database
				item_list.add_item("%s (x%d)" % [data.name, amount], data.icon)
			else:
				# Fallback if item not in database
				item_list.add_item("%s (x%d)" % [item_id, amount])
