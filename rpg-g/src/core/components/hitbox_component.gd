extends Area2D
class_name HitboxComponent

const HIT_EFFECT = preload("res://src/core/components/hit_effect.tscn")

@export var damage: int = 1
@export var knockback_force: float = 300.0
@export var continuous_damage: bool = false
@export var attack_rate: float = 0.6
@export_group("Estado alterado")
## Estado que este golpe puede infligir (opcional).
@export var status_effect: StatusEffectData
## Probabilidad (0-100) de infligir el estado en cada impacto.
@export_range(0, 100) var status_chance: float = 0.0

var _attack_timer: float = 0.0

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	# Por defecto, el hitbox está desactivado
	set_active(false)

func set_active(active: bool) -> void:
	set_deferred("monitoring", active)
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred("disabled", !active)

func _physics_process(delta: float) -> void:
	if not continuous_damage or not monitoring:
		return

	if _attack_timer > 0.0:
		_attack_timer -= delta
		return

	var overlapping: Array[Area2D] = get_overlapping_areas()
	for area: Area2D in overlapping:
		if area is HurtboxComponent:
			_apply_hit(area)
			_attack_timer = attack_rate
			break

func _on_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent:
		_apply_hit(area)
		if continuous_damage:
			_attack_timer = attack_rate

func _apply_hit(area: HurtboxComponent) -> void:
	# Calculamos la dirección simplificada desde el padre del hitbox al padre del hurtbox
	# para que el knockback tenga sentido.
	var attack_direction: Vector2 = (area.global_position - global_position).normalized()
	var inflicted: StatusEffectData = null
	if status_effect != null and randf() * 100.0 < status_chance:
		inflicted = status_effect
	area.take_hit(damage, attack_direction, knockback_force, inflicted)

	var scene_root: Node = get_tree().current_scene if get_tree() else null
	if is_instance_valid(scene_root):
		var effect: Node = HIT_EFFECT.instantiate()
		scene_root.add_child(effect)
		effect.global_position = area.global_position

