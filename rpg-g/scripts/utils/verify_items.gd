extends SceneTree

func _init():
	print("\n--- Verificando Base de Datos de Ítems ---")
	
	# Simular la carga manual si no estamos en el editor con autoloads activos
	# Pero como este script corre con 'godot -s', podemos cargar el recurso ItemDatabase directamente o buscar archivos.
	
	var data_dir = "res://assets/items/data/"
	var dir = DirAccess.open(data_dir)
	if not dir:
		print("Error: No se pudo abrir el directorio de datos: ", data_dir)
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
					print("ADVERTENCIA: ID duplicado detectado: '", item.id, "' en ", file_name, " y ", ids[item.id])
				else:
					ids[item.id] = file_name
				print("Cargado: ", item.id, " (", item.name, ") - Raridad: ", item.rarity, " - Valor: ", item.value)
			else:
				print("Error: El archivo ", file_name, " no es un ItemData válido.")
		file_name = dir.get_next()
	
	print("\nTotal de ítems encontrados: ", items_found.size())
	print("--- Verificación Completa ---\n")
	quit()
