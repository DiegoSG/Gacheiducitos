extends CharacterBody2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var hurtbox_component: HurtboxComponent = $HurtboxComponent

var health: int = 3
var is_knocked_back: bool = false

# Define how far to push (assuming 1 tile = 16px)
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
	AudioManager.play_sfx_at(&"sfx_dummy_hit", global_position)

	# Damage visual effect
	sprite.modulate = Color.RED

	# Apply the physical push
	var effective_force: float = knockback_force if knockback_force > 0.0 else KNOCKBACK_DISTANCE * 10.0
	velocity = attack_direction * effective_force

	var tween: Tween = create_tween()
	# Restore the color
	tween.tween_property(sprite, "modulate", Color.WHITE, KNOCKBACK_DURATION)

	get_tree().create_timer(KNOCKBACK_DURATION).timeout.connect(
		func() -> void:
			if is_inside_tree():
				is_knocked_back = false
	)

	# If health reaches zero, die
	if health <= 0:
		AudioManager.play_sfx(&"sfx_dummy_destroyed")
		queue_free()
