extends Node2D
class_name ShieldComponent

## Escudo PROXY (versión simple, ver design/Sistema_Armas_y_Escudo.md):
## - Bloquea el 100% del daño, el knockback y los estados alterados mientras está activo.
## - Cobertura de 360°: aún NO usa coverage_angle ni ShieldData, ni exige un escudo equipado.
## - El visual es un arco dibujado por código (placeholder, sin asset).
## No depende del jugador: el dueño decide cuándo bloquear (set_blocking) y hacia dónde mira (set_facing),
## y consulta try_block() al recibir un golpe.

signal block_started
signal block_ended
signal hit_blocked(amount_blocked: int)

## Radio del arco placeholder, en px desde el centro del dueño.
@export var radius: float = 42.0
## Apertura visual del arco (solo visual; la protección es de 360° en esta versión proxy).
@export_range(10.0, 360.0) var visual_arc_degrees: float = 120.0
@export var arc_width: float = 8.0
@export var color: Color = Color(0.55, 0.75, 1.0, 0.85)
@export var flash_color: Color = Color(1.0, 1.0, 1.0, 1.0)

var is_blocking: bool = false
var _flash_tween: Tween

func _ready() -> void:
	visible = false

func _draw() -> void:
	# Arco centrado en +X local; la orientación la da `rotation` (set_facing).
	var half: float = deg_to_rad(visual_arc_degrees) * 0.5
	draw_arc(Vector2.ZERO, radius, -half, half, 24, color, arc_width, true)

func set_blocking(value: bool) -> void:
	if is_blocking == value:
		return
	is_blocking = value
	visible = value
	AudioManager.play_sfx(&"sfx_player_block_on" if value else &"sfx_player_block_off")
	if value:
		block_started.emit()
	else:
		block_ended.emit()

## Apaga el escudo sin sonido ni señales (respawn, cambio de estado forzado).
func reset() -> void:
	is_blocking = false
	visible = false

func set_facing(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		rotation = direction.angle()

## Devuelve true si el golpe queda bloqueado. PROXY: bloquea desde cualquier dirección.
## TODO(escudo): comparar attack_direction con la dirección del dueño según coverage_angle de ShieldData.
func try_block(damage: int, _attack_direction: Vector2) -> bool:
	if not is_blocking:
		return false
	hit_blocked.emit(damage)
	_flash()
	return true

func _flash() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	modulate = flash_color * 1.6
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.15)
