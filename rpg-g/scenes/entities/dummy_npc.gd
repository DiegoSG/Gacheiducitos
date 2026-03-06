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

func _physics_process(_delta: float) -> void:
	move_and_slide()

func _on_hit_received(damage: int, attack_direction: Vector2) -> void:
	if is_knocked_back: return
	
	is_knocked_back = true
	health -= damage
	print("Dummy golpeado! HP restante: %d" % health)
	
	# Efecto visual de daño
	sprite.modulate = Color.RED
	
	# Calculamos hacia dónde será empujado
	var target_position = global_position + (attack_direction * KNOCKBACK_DISTANCE)
	
	var tween = create_tween()
	# Transición suave para el empuje
	tween.tween_property(self, "global_position", target_position, KNOCKBACK_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Restaurar el color
	tween.parallel().tween_property(sprite, "modulate", Color(0.8, 0.4, 0.4), KNOCKBACK_DURATION)
	
	await tween.finished
	is_knocked_back = false
	
	# Si su salud llega a cero, muere
	if health <= 0:
		print("Dummy destruido!")
		queue_free()
