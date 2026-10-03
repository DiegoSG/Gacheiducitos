extends Node2D

# Script para generar niveles procedurales usando Autómatas Celulares
class_name LevelGenerator

# Referencia al TileType del engine
const MGT = preload("res://src/minigames/mg_excavation/mg_excavation_types.gd")
const TileType = MGT.TileType
const WinCondition = MGT.WinCondition

static func generate_level(width: int, height: int, config: Dictionary) -> Array:
	var grid: Array = []

	# Obtener parámetros de configuración
	var densidad_tierra: float = config.get("densidad_tierra", 0.45)
	var prob_piedra: float = config.get("probabilidad_piedra", 0.15)
	var seed_value: Variant = config.get("seed", -1)
	
	# Configurar seed
	if seed_value != -1:
		seed(seed_value)
	
	# Inicializar grid vacío
	for y in range(height):
		var row: Array = []
		for x in range(width):
			row.append(TileType.EMPTY)
		grid.append(row)
	
	# Paso 1: Generar ruido inicial (tierra aleatoria)
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			if randf() < densidad_tierra:
				grid[y][x] = TileType.TIERRA
	
	# Paso 2: Aplicar Autómatas Celulares (suavizado)
	grid = _smooth_cave(grid, width, height, 3)
	
	# Paso 3: Colocar bordes de muro irrompible
	for x in range(width):
		grid[0][x] = TileType.MURO_IRROMPIBLE
		grid[height - 1][x] = TileType.MURO_IRROMPIBLE
	
	for y in range(height):
		grid[y][0] = TileType.MURO_IRROMPIBLE
		grid[y][width - 1] = TileType.MURO_IRROMPIBLE
	
	# Paso 4: Asegurar zona de inicio despejada
	for y in range(1, 4):
		for x in range(1, 4):
			grid[y][x] = TileType.EMPTY

	# Paso 5: Colocar piedras y bombas ambientales en zonas con soporte inferior
	var prob_bomba_ambiental: float = config.get("prob_bomba_ambiental", 0.04)
	for y in range(3, height - 3):
		for x in range(3, width - 3):
			if randf() < prob_piedra:
				# Solo colocar si hay algo debajo (no flotar en el aire inicialmente)
				if y < height - 1 and grid[y + 1][x] != TileType.EMPTY:
					if randf() < prob_bomba_ambiental:
						grid[y][x] = TileType.BOMBA
					else:
						grid[y][x] = TileType.PIEDRA
	
	# Paso 6: Colocar monedas (ITEM_RECOMPENSA)
	var num_monedas: int = config.get("num_monedas", 10)
	var empty_or_dirt_spaces: Array = []
	for y in range(3, height - 3):
		for x in range(3, width - 3):
			if grid[y][x] == TileType.EMPTY or grid[y][x] == TileType.TIERRA:
				empty_or_dirt_spaces.append(Vector2i(x, y))
	
	empty_or_dirt_spaces.shuffle()
	
	for i in range(min(num_monedas, empty_or_dirt_spaces.size())):
		var pos = empty_or_dirt_spaces[i]
		if pos.y < height - 1 and grid[pos.y + 1][pos.x] != TileType.EMPTY:
			grid[pos.y][pos.x] = TileType.ITEM_RECOMPENSA
		else:
			num_monedas += 1

	# Paso 6.5: Colocar ítems de inventario y bombas manuales reemplazando tierra visible
	var deliver_items = config.get("deliver_items", false)
	if deliver_items:
		var dirt_spaces = []
		for y in range(2, height - 2):
			for x in range(2, width - 2):
				if grid[y][x] == TileType.TIERRA:
					dirt_spaces.append(Vector2i(x, y))
		dirt_spaces.shuffle()
		
		# Colocar entre 3 y 6 items de inventario visibles reemplazando tierra
		var num_items_inv = randi_range(3, 6)
		for i in range(min(num_items_inv, dirt_spaces.size())):
			var p = dirt_spaces.pop_back()
			grid[p.y][p.x] = TileType.ITEM_INVENTARIO
			
		# Colocar 2-4 pickups de bombas manuales para que el jugador pueda plantar
		var num_bomb_pickups = randi_range(2, 4)
		for i in range(min(num_bomb_pickups, dirt_spaces.size())):
			var p = dirt_spaces.pop_back()
			grid[p.y][p.x] = TileType.BOMB_PICKUP

	# Paso 7: Colocar ítem de misión si es necesario
	if config.get("win_condition") == WinCondition.SPECIFIC_ITEM:
		var mission_item_placed = false
		for attempt in range(50):
			var rx = randi_range(3, width - 4)
			var ry = randi_range(3, height - 4)
			if grid[ry][rx] == TileType.EMPTY or grid[ry][rx] == TileType.TIERRA:
				grid[ry][rx] = TileType.ITEM_MISION
				mission_item_placed = true
				break
		if not mission_item_placed:
			grid[3][3] = TileType.ITEM_MISION

	# Paso 7.5: Colocar salida en la zona inferior derecha
	var exit_placed = false
	for attempt in range(50):
		var ex = randi_range(width - 10, width - 3)
		var ey = randi_range(height - 10, height - 3)
		if grid[ey][ex] == TileType.EMPTY:
			grid[ey][ex] = TileType.SALIDA
			exit_placed = true
			break
	
	if not exit_placed:
		grid[height - 2][width - 2] = TileType.SALIDA
	
	# Paso 8: Validar conectividad (Flood Fill desde inicio)
	if not _is_reachable(grid, width, height, Vector2i(1, 1)):
		return generate_level(width, height, config)
	
	return grid

# Suavizado usando reglas de autómatas celulares
static func _smooth_cave(grid: Array, width: int, height: int, iterations: int) -> Array:
	for _i in range(iterations):
		var new_grid = []
		for y in range(height):
			var row = []
			for x in range(width):
				row.append(grid[y][x])
			new_grid.append(row)
		
		for y in range(1, height - 1):
			for x in range(1, width - 1):
				var wall_count = _count_neighbors(grid, x, y, width, height)
				
				# Regla: si hay 5+ vecinos de tierra, convertir en tierra
				# Si hay 3- vecinos de tierra, convertir en vacío
				if wall_count >= 5:
					new_grid[y][x] = TileType.TIERRA
				elif wall_count <= 3:
					new_grid[y][x] = TileType.EMPTY
		
		grid = new_grid
	
	return grid

static func _count_neighbors(grid: Array, x: int, y: int, width: int, height: int) -> int:
	var count = 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			
			var nx = x + dx
			var ny = y + dy
			
			if nx < 0 or nx >= width or ny < 0 or ny >= height:
				count += 1 # Bordes cuentan como tierra
			elif grid[ny][nx] == TileType.TIERRA:
				count += 1
	
	return count

# Validar que la salida sea alcanzable desde el inicio usando Flood Fill
static func _is_reachable(grid: Array, width: int, height: int, start: Vector2i) -> bool:
	var visited = {}
	var queue = [start]
	var found_exit = false
	
	while queue.size() > 0:
		var pos = queue.pop_front()
		var key = str(pos.x) + "," + str(pos.y)
		
		if visited.has(key):
			continue
		
		visited[key] = true
		
		# Verificar si es la salida
		if grid[pos.y][pos.x] == TileType.SALIDA:
			found_exit = true
			break
		
		# Expandir a vecinos caminables
		for dir in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var next = pos + dir
			
			if next.x < 0 or next.x >= width or next.y < 0 or next.y >= height:
				continue
			
			var tile = grid[next.y][next.x]
			# Caminable: EMPTY, TIERRA (excavable), SALIDA
			if tile == TileType.EMPTY or tile == TileType.TIERRA or tile == TileType.SALIDA:
				var next_key = str(next.x) + "," + str(next.y)
				if not visited.has(next_key):
					queue.append(next)
	
	return found_exit
