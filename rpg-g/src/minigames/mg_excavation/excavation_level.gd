@tool
class_name ExcavationLevel
extends Node2D

## Root of a hand-painted excavation level.
## Expected children: a TileMapLayer using excavation_tileset.tres (the terrain) and,
## optionally, ExcavationItemMarker nodes anywhere below this node (hand-placed items).
## The level only defines the map; how the minigame is won is set on the MinigameAction.

## Wraps the painted area with unbreakable walls so the player can never leave the grid.
@export var auto_border: bool = true:
	set(value):
		auto_border = value
		update_configuration_warnings()

## Overrides the minigame item pool for random item tiles. Empty uses the action's pool.
@export var item_pool: Array[String] = []

func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	# Refresh the warnings while painting or moving markers
	var layer: TileMapLayer = get_terrain_layer()
	if layer != null and not layer.changed.is_connected(update_configuration_warnings):
		layer.changed.connect(update_configuration_warnings)
	if not child_order_changed.is_connected(update_configuration_warnings):
		child_order_changed.connect(update_configuration_warnings)

## Returns the first TileMapLayer child, which holds the painted terrain.
func get_terrain_layer() -> TileMapLayer:
	for child: Node in get_children():
		if child is TileMapLayer:
			return child as TileMapLayer
	return null

## Returns every ExcavationItemMarker below this node.
func get_item_markers() -> Array[ExcavationItemMarker]:
	var markers: Array[ExcavationItemMarker] = []
	_collect_markers(self, markers)
	return markers

func _collect_markers(node: Node, markers: Array[ExcavationItemMarker]) -> void:
	for child: Node in node.get_children():
		if child is ExcavationItemMarker:
			markers.append(child as ExcavationItemMarker)
		_collect_markers(child, markers)

func _get_configuration_warnings() -> PackedStringArray:
	return ExcavationLevelLoader.build(self).warnings
