extends Area2D
class_name HurtboxComponent

signal hit_received(damage: int, attack_direction: Vector2, knockback_force: float)

func take_hit(damage: int, attack_direction: Vector2, knockback_force: float = 0.0) -> void:
	hit_received.emit(damage, attack_direction, knockback_force)
