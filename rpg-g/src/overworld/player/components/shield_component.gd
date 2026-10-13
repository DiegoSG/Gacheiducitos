extends Node2D
class_name ShieldComponent

## Escudo (ver design/Sistema_Armas_y_Escudo.md). Los valores salen de un ShieldData:
## - Sin escudo (`shield_data` vacío) no se puede bloquear.
## - Solo cubre los golpes que llegan dentro de `coverage_angle`, centrado hacia donde mira el dueño.
## - Un golpe cubierto pierde `block_percent` de su daño; el knockback se aplica igual.
## - El visual es un arco dibujado por código (placeholder, sin asset).
## No depende del jugador: el dueño decide cuándo bloquear (set_blocking), hacia dónde mira (set_facing)
## y consulta covers_hit() / absorb() al recibir un golpe. Sirve igual para enemigos con escudo.

signal block_started
signal block_ended
signal hit_blocked(amount_blocked: int)

## Escudo equipado (el jugador lo asigna desde Inventory; un enemigo puede traerlo en la escena).
@export var shield_data: ShieldData:
	set(value):
		shield_data = value
		if shield_data == null and is_blocking:
			set_blocking(false)
		queue_redraw()
## Radio del arco placeholder, en px desde el centro del dueño.
@export var radius: float = 42.0
@export var arc_width: float = 8.0
@export var color: Color = Color(0.55, 0.75, 1.0, 0.85)
@export var flash_color: Color = Color(1.0, 1.0, 1.0, 1.0)

var is_blocking: bool = false
var _flash_tween: Tween

func _ready() -> void:
	visible = false

func _draw() -> void:
	if shield_data == null:
		return
	# Arco centrado en +X local; la orientación la da `rotation` (set_facing). Muestra la cobertura real.
	if shield_data.coverage_angle >= 360.0:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, color, arc_width, true)
		return
	var half: float = deg_to_rad(shield_data.coverage_angle) * 0.5
	draw_arc(Vector2.ZERO, radius, -half, half, 24, color, arc_width, true)

func has_shield() -> bool:
	return shield_data != null

func set_blocking(value: bool) -> void:
	if value and shield_data == null:
		value = false
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

## Multiplicador de velocidad del dueño mientras bloquea (1 si no bloquea).
func get_speed_multiplier() -> float:
	return shield_data.move_speed_multiplier if is_blocking and shield_data != null else 1.0

## true si está bloqueando y el golpe llega dentro del ángulo cubierto.
## `attack_direction` va del atacante hacia el dueño (como lo emite HurtboxComponent).
func covers_hit(attack_direction: Vector2) -> bool:
	if not is_blocking or shield_data == null:
		return false
	if shield_data.coverage_angle >= 360.0 or attack_direction == Vector2.ZERO:
		return true
	var facing: Vector2 = Vector2.RIGHT.rotated(global_rotation)
	var to_attacker: Vector2 = -attack_direction.normalized()
	return absf(rad_to_deg(facing.angle_to(to_attacker))) <= shield_data.coverage_angle * 0.5

## Aplica el porcentaje de bloqueo a un golpe cubierto y devuelve el daño que pasa.
func absorb(damage: int) -> int:
	var blocked: int = roundi(damage * shield_data.block_percent / 100.0) if shield_data else 0
	blocked = clampi(blocked, 0, damage)
	hit_blocked.emit(blocked)
	_flash()
	return damage - blocked

## true si el escudo detiene ese estado en un golpe que cubrió.
func blocks_status(status_id: String) -> bool:
	return shield_data != null and shield_data.blocks_status(status_id)

func _flash() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	modulate = flash_color * 1.6
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.15)
