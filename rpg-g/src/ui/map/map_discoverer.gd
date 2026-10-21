class_name MapDiscoverer
extends Node

## Discovers map cells around the player.
## Usage: instance as a child of any node (e.g. PlayerHUD) and assign `player`
## (if empty, looks for "Player" in GameManager.current_scene).

## Discovery radius in world units.
@export var radius: float = 300.0
## Seconds between discoveries.
@export var interval: float = 0.25
## Minimum seconds between two discovered-area sounds (while exploring, discovery happens almost every interval).
const DISCOVER_SOUND_COOLDOWN: float = 3.0

var player: Node2D

var _timer: float = 0.0
var _sound_cooldown: float = 0.0

## Level identifier used by the map: the scene path.
static func level_id_of(scene: Node) -> StringName:
	if not is_instance_valid(scene) or scene.scene_file_path.is_empty():
		return &""
	return StringName(scene.scene_file_path)

func _process(delta: float) -> void:
	_sound_cooldown = maxf(0.0, _sound_cooldown - delta)
	_timer += delta
	if _timer < interval:
		return
	_timer = 0.0
	var scene: Node = GameManager.current_scene
	if not is_instance_valid(scene):
		return
	var target: Node2D = player if is_instance_valid(player) else scene.get_node_or_null("Player") as Node2D
	if target == null:
		return
	var level_id: StringName = level_id_of(scene)
	var known_cells: int = WorldStateManager.get_discovered_cells(level_id).size()
	WorldStateManager.discover_at(level_id, target.global_position, radius)
	if _sound_cooldown <= 0.0 and WorldStateManager.get_discovered_cells(level_id).size() > known_cells:
		_sound_cooldown = DISCOVER_SOUND_COOLDOWN
		AudioManager.play_sfx(&"sfx_map_discover")
