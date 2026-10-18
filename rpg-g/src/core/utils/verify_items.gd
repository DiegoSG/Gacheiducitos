extends SceneTree

func _init():
	print("\n--- Verifying Item Database ---")

	# Simulate manual loading if we are not in the editor with autoloads active
	# But since this script runs with 'godot -s', we can load the ItemDatabase resource directly or search for files.

	var data_dir = "res://data/items/"
	var dir = DirAccess.open(data_dir)
	if not dir:
		print("Error: Could not open the data directory: ", data_dir)
		quit(1)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	var items_found = []
	var ids = {}
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path = data_dir + file_name
			var item = load(path)
			if item is ItemData:
				items_found.append(item)
				if ids.has(item.id):
					print("WARNING: Duplicate ID detected: '", item.id, "' in ", file_name, " and ", ids[item.id])
				else:
					ids[item.id] = file_name
				print("Loaded: ", item.id, " (", item.name, ") - Rarity: ", item.rarity, " - Value: ", item.value)
			else:
				print("Error: File ", file_name, " is not a valid ItemData.")
		file_name = dir.get_next()
	
	print("\nTotal items found: ", items_found.size())
	print("--- Verification Complete ---\n")
	quit()
