extends Area2D
class_name HitboxComponent

const HIT_EFFECT = preload("res://src/shared/components/hit_effect.tscn")

@export var damage: int = 1
@export var knockback_force: float = 300.0

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	# Por defecto, el hitbox está desactivado
	set_active(false)

func set_active(active: bool) -> void:
	set_deferred("monitoring", active)
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred("disabled", !active)

func _on_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent:
		# Calculamos la dirección simplificada desde el padre del hitbox al padre del hurtbox
		# para que el knockback tenga sentido.
		var attack_direction = (area.global_position - global_position).normalized()
		area.take_hit(damage, attack_direction, knockback_force)
		
		var effect = HIT_EFFECT.instantiate()
		get_tree().current_scene.add_child(effect)
		effect.global_position = area.global_position
