class_name MapDiscoverer
extends Node

## Descubre celdas del mapa alrededor del jugador.
## Uso: instanciar como hijo de cualquier nodo (p. ej. PlayerHUD) y asignar `player`
## (si queda vacío, busca "Player" en GameManager.current_scene).

## Radio de descubrimiento en unidades de mundo.
@export var radius: float = 300.0
## Segundos entre descubrimientos.
@export var interval: float = 0.25
## Segundos mínimos entre dos sonidos de zona descubierta (al explorar se descubre casi en cada intervalo).
const DISCOVER_SOUND_COOLDOWN: float = 3.0

var player: Node2D

var _timer: float = 0.0
var _sound_cooldown: float = 0.0

## Identificador de nivel usado por el mapa: ruta de la escena.
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
