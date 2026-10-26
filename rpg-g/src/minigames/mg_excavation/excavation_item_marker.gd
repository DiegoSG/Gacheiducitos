@tool
class_name ExcavationItemMarker
extends Node2D

## Hand-placed item for an ExcavationLevel. Its cell becomes a collectible item tile
## that gives exactly this item. In the editor it snaps to the center of the nearest cell
## (assumes its parent shares the TileMapLayer's origin, e.g. an "Items" node at (0, 0)).

const CELL_SIZE: int = 16

## Item id from ItemDatabase given when the cell is collected.
@export var item_id: String = "":
	set(value):
		item_id = value
		update_configuration_warnings()
		queue_redraw()

## How many units are added to the session rewards.
@export_range(1, 99, 1) var amount: int = 1

func _ready() -> void:
	if Engine.is_editor_hint():
		set_notify_local_transform(true)
		_snap_to_cell()

func _notification(what: int) -> void:
	if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED and Engine.is_editor_hint():
		_snap_to_cell()

func _snap_to_cell() -> void:
	var half: float = CELL_SIZE / 2.0
	var snapped_pos: Vector2 = (position / CELL_SIZE).floor() * CELL_SIZE + Vector2(half, half)
	if not snapped_pos.is_equal_approx(position):
		position = snapped_pos

func _draw() -> void:
	# Editor-only placeholder; the game draws items from the level grid
	if not Engine.is_editor_hint():
		return
	var half: float = CELL_SIZE / 2.0
	draw_rect(Rect2(-half, -half, CELL_SIZE, CELL_SIZE), Color(0.9, 0.4, 0.9, 0.6))
	draw_rect(Rect2(-half, -half, CELL_SIZE, CELL_SIZE), Color.WHITE, false, 1.0)
	if not item_id.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(-half, -half - 2), item_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = PackedStringArray()
	if item_id.is_empty():
		warnings.append("Set item_id to the ItemDatabase id this cell gives.")
	return warnings
