@tool
class_name ExcavationLevelData
extends RefCounted

## Plain level data consumed by MG_ExcavationGame.
## Produced by LevelGenerator (procedural) or ExcavationLevelLoader (painted TileMapLayer).

const MGT = preload("res://src/minigames/mg_excavation/mg_excavation_types.gd")
const TileType = MGT.TileType

## Grid size in cells.
var size: Vector2i = Vector2i.ZERO
## Tile grid indexed as grid[y][x], values from TileType.
var grid: Array = []
## Cell where the player starts.
var player_start: Vector2i = Vector2i(1, 1)
## Specific rewards for ITEM_INVENTARIO cells: Vector2i -> {"id": String, "amount": int}.
## Cells without an entry fall back to the minigame item pool.
var cell_items: Dictionary = {}
## Overrides the minigame item pool for random item cells. Empty keeps the minigame's pool.
var item_pool: Array[String] = []

## Creates an EMPTY grid of the given size.
static func create_empty(level_size: Vector2i) -> ExcavationLevelData:
	var data: ExcavationLevelData = ExcavationLevelData.new()
	data.size = level_size
	data.grid.clear()
	for y: int in range(level_size.y):
		var row: Array = []
		row.resize(level_size.x)
		row.fill(TileType.EMPTY)
		data.grid.append(row)
	return data

## Returns how many cells hold the given tile type.
func count_tiles(tile_type: int) -> int:
	var count: int = 0
	for row: Array in grid:
		count += row.count(tile_type)
	return count
