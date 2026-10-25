class_name MapCanvas
extends Control

## Dibuja la grilla del mapa (arte provisional). No conoce al jugador ni a GameManager.

const COLOR_UNKNOWN: Color = Color(0.08, 0.09, 0.12)
const COLOR_KNOWN: Color = Color(0.72, 0.76, 0.68)
const COLOR_GRID: Color = Color(0.0, 0.0, 0.0, 0.35)
const COLOR_POI: Color = Color(1.0, 0.8, 0.2)
const COLOR_PLAYER: Color = Color(0.9, 0.2, 0.2)

var level_id: StringName = &""
var level_bounds: Vector2 = Vector2(3840.0, 2160.0)
var view_center: Vector2 = Vector2.ZERO
var zoom: float = 0.2
var player_pos: Variant = null
var pois: Array[Dictionary] = []

func world_to_screen(p: Vector2) -> Vector2:
	return (p - view_center) * zoom + size * 0.5

func _draw() -> void:
	var cell: Vector2 = WorldStateManager.map_cell_size
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_UNKNOWN)
	var cols: int = ceili(level_bounds.x / cell.x)
	var rows: int = ceili(level_bounds.y / cell.y)
	for cx: int in range(cols):
		for cy: int in range(rows):
			var r: Rect2 = Rect2(world_to_screen(Vector2(cx, cy) * cell), cell * zoom)
			if not Rect2(Vector2.ZERO, size).intersects(r):
				continue
			if WorldStateManager.is_discovered(level_id, Vector2i(cx, cy)):
				draw_rect(r, COLOR_KNOWN)
			draw_rect(r, COLOR_GRID, false, 1.0)
	var font: Font = ThemeDB.fallback_font
	for poi: Dictionary in pois:
		var sp: Vector2 = world_to_screen(poi["world_pos"])
		var d: float = 9.0
		draw_colored_polygon(PackedVector2Array([
			sp + Vector2(0, -d), sp + Vector2(d, 0), sp + Vector2(0, d), sp + Vector2(-d, 0)]), COLOR_POI)
		draw_string(font, sp + Vector2(d + 4.0, 5.0), str(poi["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COLOR_POI)
	if player_pos is Vector2:
		var pp: Vector2 = world_to_screen(player_pos as Vector2)
		draw_circle(pp, 7.0, COLOR_PLAYER)
		draw_arc(pp, 10.0, 0.0, TAU, 24, Color.WHITE, 2.0)
