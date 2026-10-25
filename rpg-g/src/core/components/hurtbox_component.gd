extends Area2D
class_name HurtboxComponent

signal hit_received(damage: int, attack_direction: Vector2, knockback_force: float)
## Se emite ademas de hit_received cuando el golpe inflige un estado alterado.
signal status_inflicted(effect: StatusEffectData)

func take_hit(damage: int, attack_direction: Vector2, knockback_force: float = 0.0, status: StatusEffectData = null) -> void:
	hit_received.emit(damage, attack_direction, knockback_force)
	if status != null:
		status_inflicted.emit(status)
