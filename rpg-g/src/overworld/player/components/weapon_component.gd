extends Node
class_name WeaponComponent

## Ataque cuerpo a cuerpo con el arma equipada (ver design/Sistema_Armas_y_Escudo.md).
## Configura el HitboxComponent según el WeaponData (daño, alcance, knockback, estado, visual),
## lo activa un instante y respeta el cooldown del arma. Sin arma: golpe base con la fuerza.
## No depende del jugador: el dueño asigna el arma (set_weapon) y llama a attack().

signal attack_started
signal attack_finished

## Hitbox que golpea. Su primer CollisionShape2D (rectángulo) se redimensiona con `reach`.
@export var hitbox: HitboxComponent
## Visual del golpe (opcional).
@export var slash_sprite: Sprite2D
## Segundos que el hitbox queda activo.
@export var swing_duration: float = 0.18
## Distancia desde el centro del dueño hasta el borde cercano de la zona de golpe.
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
			# Copia propia: la forma del .tscn se comparte entre instancias de la escena
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

## Daño total de un golpe con la fuerza dada.
func get_damage(strength: int) -> int:
	return strength + (weapon.damage if weapon else 0)

## Golpea una vez. Espera hasta que el golpe termina (el dueño puede hacer `await`).
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

## Corta un golpe en curso (muerte, respawn).
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

## Ajusta el tamaño y la posición de la zona de golpe (y del visual) al alcance del arma.
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
