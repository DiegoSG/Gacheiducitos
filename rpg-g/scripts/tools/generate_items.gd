@tool
extends EditorScript

func _run() -> void:
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("assets/items/data"):
		dir.make_dir_recursive("assets/items/data")
	
	create_item("red_potion", "Poción Roja", "res://assets/items/icon_red.png", "Una poción de color carmesí.")
	create_item("green_herb", "Hierba Verde", "res://assets/items/icon_green.png", "Huele a bosque.")
	create_item("blue_gem", "Gema Azul", "res://assets/items/icon_blue.png", "Brilla intensamente.")
	
	print("Item resources generated successfully!")

func create_item(id: String, name: String, icon_path: String, desc: String) -> void:
	var item = ItemData.new()
	item.id = id
	item.name = name
	item.description = desc
	item.icon = load(icon_path)
	item.item_scale = Vector2(0.3, 0.3)
	
	var save_path = "res://assets/items/data/" + id + ".tres"
	ResourceSaver.save(item, save_path)
	print("Saved: ", save_path)
