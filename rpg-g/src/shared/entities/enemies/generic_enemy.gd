extends CharacterBody2D

@export var speed: float = 70.0
@export var max_health: int = 3
@export var has_iframes: bool = true
@export var iframe_duration: float = 0.6
var current_health: int = 3

@onready var detection_zone: Area2D = $DetectionZone
@onready var hitbox_component: HitboxComponent = $HitboxComponent
@onready var hurtbox_component: HurtboxComponent = $HurtboxComponent

var player: CharacterBody2D = null

enum State {
	IDLE,
	CHASE
}
var current_state = State.IDLE
var is_stunned: bool = false
var is_invulnerable: bool = false

func _ready():
	add_to_group("enemy")
	current_health = max_health
	
	detection_zone.body_entered.connect(_on_body_entered)
	detection_zone.body_exited.connect(_on_body_exited)
	
	if hurtbox_component:
		hurtbox_component.hit_received.connect(_on_hit_received)
		
	if hitbox_component:
		# Activamos el hitbox permanentemente para que lastime al tocar
		hitbox_component.set_active(true)

func _physics_process(delta):
	if is_stunned:
		velocity = velocity.move_toward(Vector2.ZERO, speed * 15 * delta)
		move_and_slide()
		return
		
	if current_state == State.CHASE and player != null:
		var direction = global_position.direction_to(player.global_position)
		velocity = direction * speed
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed * 4 * delta)
		
	move_and_slide()

func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		player = body as CharacterBody2D
		current_state = State.CHASE

func _on_body_exited(body: Node2D):
	if body == player:
		player = null
		current_state = State.IDLE

func _on_hit_received(damage: int, attack_direction: Vector2, knockback_force: float):
	if is_invulnerable: return
	
	current_health -= damage
	print("Enemy hit! Health: ", current_health)
	
	# Componente físico del empujón
	velocity = attack_direction * knockback_force
	
	if current_health <= 0:
		queue_free()
		return
		
	is_stunned = true
	get_tree().create_timer(0.3).timeout.connect(func(): if is_inside_tree(): is_stunned = false)
	
	if has_iframes and iframe_duration > 0.0:
		is_invulnerable = true
		
		# Efecto visual de parpadeo temporal (0.2s por loop completo)
		var blink_time = 0.1
		var loops = int(max(1.0, iframe_duration / (blink_time * 2)))
		
		var tween = create_tween()
		tween.set_loops(loops)
		tween.tween_property($Sprite2D, "modulate:a", 0.2, blink_time)
		tween.tween_property($Sprite2D, "modulate:a", 1.0, blink_time)
		
		get_tree().create_timer(iframe_duration).timeout.connect(func(): if is_inside_tree(): is_invulnerable = false)
