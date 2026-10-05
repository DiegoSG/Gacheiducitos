extends CharacterBody2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var hurtbox_component: HurtboxComponent = $HurtboxComponent

var health: int = 3
var is_knocked_back: bool = false

# Definimos cuánto se empuja (asumiendo 1 cuadro = 16px)
const KNOCKBACK_DISTANCE = 16.0
const KNOCKBACK_DURATION = 0.2

func _ready() -> void:
	hurtbox_component.hit_received.connect(_on_hit_received)
	add_to_group("enemy")

func _physics_process(delta: float) -> void:
	if is_knocked_back:
		velocity = velocity.move_toward(Vector2.ZERO, KNOCKBACK_DISTANCE * 10 * delta)
	move_and_slide()

func _on_hit_received(damage: int, attack_direction: Vector2, knockback_force: float) -> void:
	if is_knocked_back:
		return

	is_knocked_back = true
	health -= damage
	AudioManager.play_sfx(&"sfx_dummy_hit")

	# Efecto visual de daño
	sprite.modulate = Color.RED

	# Aplicar el empuje físico
	var effective_force: float = knockback_force if knockback_force > 0.0 else KNOCKBACK_DISTANCE * 10.0
	velocity = attack_direction * effective_force

	var tween: Tween = create_tween()
	# Restaurar el color
	tween.tween_property(sprite, "modulate", Color.WHITE, KNOCKBACK_DURATION)

	get_tree().create_timer(KNOCKBACK_DURATION).timeout.connect(
		func() -> void:
			if is_inside_tree():
				is_knocked_back = false
	)

	# Si su salud llega a cero, muere
	if health <= 0:
		AudioManager.play_sfx(&"sfx_dummy_destroyed")
		queue_free()
