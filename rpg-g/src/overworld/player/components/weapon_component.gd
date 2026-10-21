extends Node
class_name WeaponComponent

## Melee attack with the equipped weapon (see design/Sistema_Armas_y_Escudo.md).
## Configures the HitboxComponent from the WeaponData (damage, reach, knockback, status, visual),
## activates it briefly and respects the weapon's cooldown. No weapon: base strike with strength.
## Does not depend on the player: the owner assigns the weapon (set_weapon) and calls attack().

signal attack_started
signal attack_finished

## Hitbox that strikes. Its first CollisionShape2D (rectangle) is resized by `reach`.
@export var hitbox: HitboxComponent
## Hit visual (optional).
@export var slash_sprite: Sprite2D
## Seconds the hitbox stays active.
@export var swing_duration: float = 0.18
## Distance from the owner's center to the near edge of the strike zone.
@export var reach_offset: float = 30.0

var weapon: WeaponData = null
var is_swinging: bool = false

var _cooldown_left: float = 0.0
var _shape: RectangleShape2D = null
var _base_reach: Vector2 = Vector2(60, 60)
var _base_knockback: float = 300.0
var _base_slash_texture: Texture2D = null
var _base_slash_offset: float = 60.0

func _ready() -> void:
	if hitbox:
		_base_knockback = hitbox.knockback_force
		var shape_node: CollisionShape2D = _find_shape_node()
		if shape_node and shape_node.shape is RectangleShape2D:
			# Own copy: the .tscn shape is shared between instances of the scene
			_shape = (shape_node.shape as RectangleShape2D).duplicate()
			shape_node.shape = _shape
			_base_reach = _shape.size
	if slash_sprite:
		_base_slash_texture = slash_sprite.texture
		_base_slash_offset = slash_sprite.position.y
		slash_sprite.visible = false
	_apply_shape()

func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)

func set_weapon(data: WeaponData) -> void:
	weapon = data
	_apply_shape()

func can_attack() -> bool:
	return not is_swinging and _cooldown_left <= 0.0

## Total damage of a strike with the given strength.
func get_damage(strength: int) -> int:
	return strength + (weapon.damage if weapon else 0)

## Strikes once. Waits until the strike ends (the owner may `await` it).
func attack(strength: int) -> void:
	if not can_attack() or hitbox == null:
		return
	is_swinging = true
	hitbox.damage = get_damage(strength)
	hitbox.knockback_force = weapon.knockback if weapon else _base_knockback
	hitbox.status_effect = weapon.status_effect if weapon else null
	hitbox.status_chance = weapon.status_chance if weapon else 0.0
	attack_started.emit()
	_play_slash()
	hitbox.set_active(true)
	await get_tree().create_timer(swing_duration).timeout
	if not is_inside_tree():
		return
	hitbox.set_active(false)
	if slash_sprite:
		slash_sprite.visible = false
	is_swinging = false
	_cooldown_left = weapon.cooldown if weapon else 0.0
	attack_finished.emit()

## Cancels a strike in progress (death, respawn).
func cancel() -> void:
	if hitbox:
		hitbox.set_active(false)
	if slash_sprite:
		slash_sprite.visible = false

func _play_slash() -> void:
	if not slash_sprite:
		return
	slash_sprite.visible = true
	slash_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	slash_sprite.scale = Vector2(0.06, 0.06)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(slash_sprite, "scale", Vector2(0.13, 0.13), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(slash_sprite, "modulate:a", 0.0, 0.15)

## Adjusts the size and position of the strike zone (and visual) to the weapon's reach.
func _apply_shape() -> void:
	var reach: Vector2 = weapon.reach if weapon else _base_reach
	var shape_node: CollisionShape2D = _find_shape_node()
	if _shape and shape_node:
		_shape.size = reach
		shape_node.position.y = reach_offset + reach.y * 0.5
	if slash_sprite:
		slash_sprite.texture = weapon.slash_texture if weapon and weapon.slash_texture else _base_slash_texture
		slash_sprite.position.y = (reach_offset + reach.y * 0.5) if weapon else _base_slash_offset

func _find_shape_node() -> CollisionShape2D:
	if hitbox == null:
		return null
	for child: Node in hitbox.get_children():
		if child is CollisionShape2D:
			return child as CollisionShape2D
	return null
