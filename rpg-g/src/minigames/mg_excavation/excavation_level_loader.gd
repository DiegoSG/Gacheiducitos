@tool
class_name ExcavationLevelLoader
extends RefCounted

## Converts a painted ExcavationLevel (TileMapLayer + ExcavationItemMarker nodes)
## into ExcavationLevelData. Tiles are recognized by the TileSet custom data layer
## CUSTOM_DATA_NAME, whose int value is a TileType.

const MGT = preload("res://src/minigames/mg_excavation/mg_excavation_types.gd")
const TileType = MGT.TileType

const CUSTOM_DATA_NAME: String = "excavation_tile"

## Result of a conversion: the level data plus the problems found while building it.
class LoadResult:
	var data: ExcavationLevelData = null
	var warnings: PackedStringArray = PackedStringArray()

## Loads a level scene, converts it and frees the instance. Returns null if the scene is not an ExcavationLevel.
static func load_scene(scene_path: String) -> ExcavationLevelData:
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("ExcavationLevelLoader: cannot load level scene '%s'." % scene_path)
		return null
	var instance: Node = packed.instantiate()
	var level: ExcavationLevel = instance as ExcavationLevel
	if level == null:
		push_error("ExcavationLevelLoader: the root of '%s' is not an ExcavationLevel." % scene_path)
		instance.free()
		return null
	var result: LoadResult = build(level)
	for warning: String in result.warnings:
		push_warning("ExcavationLevelLoader (%s): %s" % [scene_path, warning])
	instance.free()
	return result.data

## Builds the level data from an ExcavationLevel node (inside or outside the scene tree).
static func build(level: ExcavationLevel) -> LoadResult:
	var result: LoadResult = LoadResult.new()
	# TileMapLayer is preferred; a legacy TileMap node (layer 0) is also read
	var terrain: Node2D = level.get_terrain_node()
	if terrain == null:
		result.warnings.append("The level has no TileMapLayer child to read tiles from.")
		return result
	if terrain is TileMap:
		result.warnings.append("Terrain uses the deprecated TileMap node; only its first layer is read. Prefer a TileMapLayer.")
	var tile_set: TileSet = _get_tile_set(terrain)
	if tile_set == null or tile_set.get_custom_data_layer_by_name(CUSTOM_DATA_NAME) < 0:
		result.warnings.append("The TileSet has no '%s' custom data layer." % CUSTOM_DATA_NAME)
		return result

	var used_rect: Rect2i = _get_used_rect(terrain)
	if used_rect.size == Vector2i.ZERO:
		result.warnings.append("Nothing is painted on the terrain.")
		return result

	# With auto_border the painted area is wrapped by one ring of unbreakable walls
	var border: int = 1 if level.auto_border else 0
	var origin: Vector2i = used_rect.position - Vector2i(border, border)
	var data: ExcavationLevelData = ExcavationLevelData.create_empty(used_rect.size + Vector2i(border, border) * 2)
	data.item_pool = level.item_pool.duplicate()
	result.data = data

	if level.auto_border:
		for x: int in range(data.size.x):
			data.grid[0][x] = TileType.MURO_IRROMPIBLE
			data.grid[data.size.y - 1][x] = TileType.MURO_IRROMPIBLE
		for y: int in range(data.size.y):
			data.grid[y][0] = TileType.MURO_IRROMPIBLE
			data.grid[y][data.size.x - 1] = TileType.MURO_IRROMPIBLE

	var start_count: int = 0
	for map_cell: Vector2i in _get_used_cells(terrain):
		var tile_data: TileData = _get_cell_tile_data(terrain, map_cell)
		if tile_data == null:
			continue
		var tile_type: int = int(tile_data.get_custom_data(CUSTOM_DATA_NAME))
		var cell: Vector2i = map_cell - origin
		if tile_type == TileType.PLAYER_START:
			data.player_start = cell
			start_count += 1
		else:
			data.grid[cell.y][cell.x] = tile_type

	# Hand-placed items: each marker turns its cell into an item with a specific reward
	var terrain_from_level: Transform2D = _transform_to_ancestor(terrain, level).affine_inverse()
	for marker: ExcavationItemMarker in level.get_item_markers():
		var level_pos: Vector2 = _transform_to_ancestor(marker, level).origin
		var cell: Vector2i = _local_to_map(terrain, terrain_from_level * level_pos) - origin
		if not Rect2i(Vector2i.ZERO, data.size).has_point(cell):
			result.warnings.append("Item marker '%s' is outside the painted area." % marker.name)
			continue
		if marker.item_id.is_empty():
			result.warnings.append("Item marker '%s' has no item_id." % marker.name)
			continue
		data.grid[cell.y][cell.x] = TileType.ITEM_INVENTARIO
		data.cell_items[cell] = {"id": marker.item_id, "amount": marker.amount}

	# Validation (warnings only, the level still loads)
	if start_count == 0:
		result.warnings.append("No player start tile; the player starts at %s." % str(data.player_start))
	elif start_count > 1:
		result.warnings.append("%d player start tiles; only one is used." % start_count)
	if not Rect2i(Vector2i.ZERO, data.size).has_point(data.player_start):
		data.player_start = Vector2i.ZERO
	data.grid[data.player_start.y][data.player_start.x] = TileType.EMPTY

	var exit_count: int = data.count_tiles(TileType.SALIDA)
	if exit_count == 0:
		result.warnings.append("No exit tile; only goals with require_exit = false can be won.")
	elif not _is_exit_reachable_ignoring_rocks(data):
		result.warnings.append("The exit is sealed off by unbreakable walls.")

	return result

# TileMapLayer and the legacy TileMap expose the same queries with different signatures
static func _get_tile_set(terrain: Node2D) -> TileSet:
	if terrain is TileMap:
		return (terrain as TileMap).tile_set
	return (terrain as TileMapLayer).tile_set

static func _get_used_rect(terrain: Node2D) -> Rect2i:
	if terrain is TileMap:
		return (terrain as TileMap).get_used_rect()
	return (terrain as TileMapLayer).get_used_rect()

static func _local_to_map(terrain: Node2D, local_pos: Vector2) -> Vector2i:
	if terrain is TileMap:
		return (terrain as TileMap).local_to_map(local_pos)
	return (terrain as TileMapLayer).local_to_map(local_pos)

static func _get_used_cells(terrain: Node2D) -> Array[Vector2i]:
	if terrain is TileMap:
		return (terrain as TileMap).get_used_cells(0)
	return (terrain as TileMapLayer).get_used_cells()

static func _get_cell_tile_data(terrain: Node2D, cell: Vector2i) -> TileData:
	if terrain is TileMap:
		return (terrain as TileMap).get_cell_tile_data(0, cell)
	return (terrain as TileMapLayer).get_cell_tile_data(cell)

# Transform of node expressed in ancestor's local space (works outside the scene tree).
static func _transform_to_ancestor(node: Node, ancestor: Node) -> Transform2D:
	var xf: Transform2D = Transform2D.IDENTITY
	var current: Node = node
	while current != null and current != ancestor:
		if current is Node2D:
			xf = (current as Node2D).transform * xf
		current = current.get_parent()
	return xf

# Returns true if some exit can be reached from the start when every cell except
# unbreakable walls is considered passable (rocks can be pushed or blown up).
static func _is_exit_reachable_ignoring_rocks(data: ExcavationLevelData) -> bool:
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [data.player_start]
	var bounds: Rect2i = Rect2i(Vector2i.ZERO, data.size)
	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()
		if visited.has(pos):
			continue
		visited[pos] = true
		if data.grid[pos.y][pos.x] == TileType.SALIDA:
			return true
		for dir: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = pos + dir
			if bounds.has_point(next) and not visited.has(next) and data.grid[next.y][next.x] != TileType.MURO_IRROMPIBLE:
				queue.append(next)
	return false
