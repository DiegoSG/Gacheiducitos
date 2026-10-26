extends RefCounted

# Script to generate procedural levels using Cellular Automata
class_name LevelGenerator

# Reference to the engine's TileType
const MGT = preload("res://src/minigames/mg_excavation/mg_excavation_types.gd")
const TileType = MGT.TileType
const WinCondition = MGT.WinCondition

# Attempts before giving up on a level whose exit is reachable
const MAX_GENERATION_ATTEMPTS: int = 50

const PLAYER_START: Vector2i = Vector2i(1, 1)

static func generate_level(width: int, height: int, config: Dictionary) -> ExcavationLevelData:
	# Own RNG so a fixed seed does not make the global RNG deterministic
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var seed_value: Variant = config.get("seed", -1)
	if seed_value != -1:
		rng.seed = int(seed_value)
	else:
		rng.randomize()

	# Each attempt keeps advancing the same RNG, so a fixed seed still produces new layouts
	var grid: Array = []
	for _attempt: int in range(MAX_GENERATION_ATTEMPTS):
		grid = _generate_grid(width, height, config, rng)
		if is_exit_reachable(grid, width, height, PLAYER_START):
			break
	if not is_exit_reachable(grid, width, height, PLAYER_START):
		push_warning("LevelGenerator: no level with a reachable exit after %d attempts." % MAX_GENERATION_ATTEMPTS)

	var data: ExcavationLevelData = ExcavationLevelData.new()
	data.size = Vector2i(width, height)
	data.grid = grid
	data.player_start = PLAYER_START
	return data

static func _generate_grid(width: int, height: int, config: Dictionary, rng: RandomNumberGenerator) -> Array:
	var grid: Array = []

	# Get configuration parameters
	var densidad_tierra: float = config.get("densidad_tierra", 0.45)
	var prob_piedra: float = config.get("probabilidad_piedra", 0.15)

	# Initialize empty grid
	for y in range(height):
		var row: Array = []
		for x in range(width):
			row.append(TileType.EMPTY)
		grid.append(row)

	# Step 1: Generate initial noise (random dirt)
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			if rng.randf() < densidad_tierra:
				grid[y][x] = TileType.TIERRA

	# Step 2: Apply cellular automata (smoothing)
	grid = _smooth_cave(grid, width, height, 3)

	# Step 3: Place unbreakable wall borders
	for x in range(width):
		grid[0][x] = TileType.MURO_IRROMPIBLE
		grid[height - 1][x] = TileType.MURO_IRROMPIBLE

	for y in range(height):
		grid[y][0] = TileType.MURO_IRROMPIBLE
		grid[y][width - 1] = TileType.MURO_IRROMPIBLE

	# Step 4: Clear the start area
	for y in range(1, 4):
		for x in range(1, 4):
			grid[y][x] = TileType.EMPTY

	# Step 5: Place rocks and ambient bombs in areas with support below
	var prob_bomba_ambiental: float = config.get("prob_bomba_ambiental", 0.04)
	for y in range(3, height - 3):
		for x in range(3, width - 3):
			if rng.randf() < prob_piedra:
				# Only place if there is something below (don't float in mid-air initially)
				if y < height - 1 and grid[y + 1][x] != TileType.EMPTY:
					if rng.randf() < prob_bomba_ambiental:
						grid[y][x] = TileType.BOMBA
					else:
						grid[y][x] = TileType.PIEDRA

	# Step 6: Place coins (ITEM_RECOMPENSA)
	var num_monedas: int = config.get("num_monedas", 10)
	var empty_or_dirt_spaces: Array = []
	for y in range(3, height - 3):
		for x in range(3, width - 3):
			if grid[y][x] == TileType.EMPTY or grid[y][x] == TileType.TIERRA:
				empty_or_dirt_spaces.append(Vector2i(x, y))

	_shuffle(empty_or_dirt_spaces, rng)

	# Walk the candidates until the requested amount is placed (coins need support below)
	var coins_placed: int = 0
	for pos: Vector2i in empty_or_dirt_spaces:
		if coins_placed >= num_monedas:
			break
		if pos.y < height - 1 and grid[pos.y + 1][pos.x] != TileType.EMPTY:
			grid[pos.y][pos.x] = TileType.ITEM_RECOMPENSA
			coins_placed += 1

	# Step 6.5: Place inventory items and manual bombs, replacing visible dirt
	var deliver_items = config.get("deliver_items", false)
	if deliver_items:
		var dirt_spaces = []
		for y in range(2, height - 2):
			for x in range(2, width - 2):
				if grid[y][x] == TileType.TIERRA:
					dirt_spaces.append(Vector2i(x, y))
		_shuffle(dirt_spaces, rng)

		# Place 3 to 6 visible inventory items, replacing dirt
		var num_items_inv = rng.randi_range(3, 6)
		for i in range(min(num_items_inv, dirt_spaces.size())):
			var p = dirt_spaces.pop_back()
			grid[p.y][p.x] = TileType.ITEM_INVENTARIO

		# Place 2-4 manual bomb pickups so the player can plant bombs
		var num_bomb_pickups = rng.randi_range(2, 4)
		for i in range(min(num_bomb_pickups, dirt_spaces.size())):
			var p = dirt_spaces.pop_back()
			grid[p.y][p.x] = TileType.BOMB_PICKUP

	# Step 7: Place mission item if needed
	if config.get("win_condition") == WinCondition.SPECIFIC_ITEM:
		var mission_item_placed = false
		for attempt in range(50):
			var rx = rng.randi_range(3, width - 4)
			var ry = rng.randi_range(3, height - 4)
			if grid[ry][rx] == TileType.EMPTY or grid[ry][rx] == TileType.TIERRA:
				grid[ry][rx] = TileType.ITEM_MISION
				mission_item_placed = true
				break
		if not mission_item_placed:
			grid[3][3] = TileType.ITEM_MISION

	# Step 7.5: Place exit in the bottom-right area
	var exit_placed = false
	for attempt in range(50):
		var ex = rng.randi_range(width - 10, width - 3)
		var ey = rng.randi_range(height - 10, height - 3)
		if grid[ey][ex] == TileType.EMPTY:
			grid[ey][ex] = TileType.SALIDA
			exit_placed = true
			break

	if not exit_placed:
		grid[height - 2][width - 2] = TileType.SALIDA

	return grid

# Fisher-Yates shuffle with the generator's RNG (Array.shuffle uses the global one)
static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i: int in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

# Smoothing using cellular automata rules
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

				# Rule: if 5+ dirt neighbors, turn into dirt
				# If 3 or fewer dirt neighbors, turn into empty
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
				count += 1 # Borders count as dirt
			elif grid[ny][nx] == TileType.TIERRA:
				count += 1

	return count

## Returns whether the exit can be reached from start through EMPTY, TIERRA or SALIDA cells (flood fill).
static func is_exit_reachable(grid: Array, width: int, height: int, start: Vector2i) -> bool:
	var visited = {}
	var queue = [start]
	var found_exit = false

	while queue.size() > 0:
		var pos = queue.pop_front()
		var key = str(pos.x) + "," + str(pos.y)

		if visited.has(key):
			continue

		visited[key] = true

		# Check whether this is the exit
		if grid[pos.y][pos.x] == TileType.SALIDA:
			found_exit = true
			break

		# Expand to walkable neighbors
		for dir in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var next = pos + dir

			if next.x < 0 or next.x >= width or next.y < 0 or next.y >= height:
				continue

			var tile = grid[next.y][next.x]
			# Walkable: EMPTY, TIERRA (diggable), SALIDA
			if tile == TileType.EMPTY or tile == TileType.TIERRA or tile == TileType.SALIDA:
				var next_key = str(next.x) + "," + str(next.y)
				if not visited.has(next_key):
					queue.append(next)

	return found_exit
