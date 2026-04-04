@tool
extends EditorScript

func _run() -> void:
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("assets/items"):
		dir.make_dir_recursive("assets/items")
	
	create_icon("res://assets/items/icon_red.png", Color.RED)
	create_icon("res://assets/items/icon_green.png", Color.GREEN)
	create_icon("res://assets/items/icon_blue.png", Color.BLUE)
	
	print("Icons generated successfully!")

func create_icon(path: String, color: Color) -> void:
	var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(color)
	image.save_png(path)
