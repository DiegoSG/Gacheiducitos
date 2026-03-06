extends Area2D
class_name HurtboxComponent

signal hit_received(damage: int, attack_direction: Vector2)

func take_hit(damage: int, attack_direction: Vector2) -> void:
	hit_received.emit(damage, attack_direction)
