extends Node2D
class_name ShieldComponent

## Shield (see design/Sistema_Armas_y_Escudo.md). Values come from a ShieldData:
## - Without a shield (`shield_data` empty), blocking is not possible.
## - Only covers hits arriving within `coverage_angle`, centered toward where the owner faces.
## - A covered hit loses `block_percent` of its damage; knockback still applies.
## - The visual is an arc drawn in code (placeholder, no asset).
## Does not depend on the player: the owner decides when to block (set_blocking) and where it faces (set_facing)
## and queries covers_hit() / absorb() when receiving a hit. Works the same for enemies with shields.

signal block_started
signal block_ended
signal hit_blocked(amount_blocked: int)

## Equipped shield (the player assigns it from Inventory; an enemy can bring it into the scene).
@export var shield_data: ShieldData:
	set(value):
		shield_data = value
		if shield_data == null and is_blocking:
			set_blocking(false)
		queue_redraw()
## Radius of the placeholder arc, in px from the owner's center.
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
	# Arc centered on local +X; orientation is given by `rotation` (set_facing). Shows the real coverage.
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

## Turns off the shield without sound or signals (respawn, forced state change).
func reset() -> void:
	is_blocking = false
	visible = false

func set_facing(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		rotation = direction.angle()

## Owner's speed multiplier while blocking (1 if not blocking).
func get_speed_multiplier() -> float:
	return shield_data.move_speed_multiplier if is_blocking and shield_data != null else 1.0

## true if blocking and the hit arrives within the covered angle.
## `attack_direction` goes from the attacker to the owner (as HurtboxComponent emits it).
func covers_hit(attack_direction: Vector2) -> bool:
	if not is_blocking or shield_data == null:
		return false
	if shield_data.coverage_angle >= 360.0 or attack_direction == Vector2.ZERO:
		return true
	var facing: Vector2 = Vector2.RIGHT.rotated(global_rotation)
	var to_attacker: Vector2 = -attack_direction.normalized()
	return absf(rad_to_deg(facing.angle_to(to_attacker))) <= shield_data.coverage_angle * 0.5

## Applies the block percentage to a covered hit and returns the damage that gets through.
func absorb(damage: int) -> int:
	var blocked: int = roundi(damage * shield_data.block_percent / 100.0) if shield_data else 0
	blocked = clampi(blocked, 0, damage)
	hit_blocked.emit(blocked)
	_flash()
	return damage - blocked

## true if the shield stops that state on a hit it covered.
func blocks_status(status_id: String) -> bool:
	return shield_data != null and shield_data.blocks_status(status_id)

func _flash() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	modulate = flash_color * 1.6
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.15)
