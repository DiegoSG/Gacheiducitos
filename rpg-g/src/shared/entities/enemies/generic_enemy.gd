extends CharacterBody2D

@export var speed: float = 70.0
@export var max_health: int = 3
@export var has_iframes: bool = true
@export var iframe_duration: float = 0.6
@export var cooldown_duration: float = 10.0
@export var return_to_start_position: bool = true
@export var return_speed: float = 70.0
var current_health: int = 3

@onready var vision_zone: Area2D = get_node_or_null("VisionZone") if get_node_or_null("VisionZone") else get_node_or_null("DetectionZone")
@onready var lose_target_zone: Area2D = get_node_or_null("LoseTargetZone")
@onready var hitbox_component: HitboxComponent = $HitboxComponent
@onready var hurtbox_component: HurtboxComponent = $HurtboxComponent

var player: CharacterBody2D = null

enum State {
	IDLE,
	CHASE,
	COOLDOWN,
	RETURNING
}
var current_state: State = State.IDLE
var is_stunned: bool = false
var is_invulnerable: bool = false

var _start_position: Vector2 = Vector2.ZERO
var _cooldown_timer: float = 0.0

func _ready() -> void:
	add_to_group("enemy")
	current_health = max_health
	_start_position = global_position
	
	if vision_zone:
		vision_zone.body_entered.connect(_on_vision_entered)
	
	if lose_target_zone:
		lose_target_zone.body_entered.connect(_on_lose_target_entered)
		lose_target_zone.body_exited.connect(_on_lose_target_exited)
	elif vision_zone:
		# Fallback de compatibilidad si solo hay una zona
		vision_zone.body_exited.connect(_on_lose_target_exited)
	
	if hurtbox_component:
		hurtbox_component.hit_received.connect(_on_hit_received)
		
	if hitbox_component:
		# Activamos el hitbox permanentemente para que lastime al tocar
		hitbox_component.set_active(true)

func _physics_process(delta: float) -> void:
	if is_stunned:
		velocity = velocity.move_toward(Vector2.ZERO, speed * 15 * delta)
		move_and_slide()
		return
		
	match current_state:
		State.CHASE:
			if player != null:
				var direction = global_position.direction_to(player.global_position)
				velocity = direction * speed
			else:
				velocity = velocity.move_toward(Vector2.ZERO, speed * 4 * delta)
		State.COOLDOWN:
			velocity = velocity.move_toward(Vector2.ZERO, speed * 4 * delta)
			_cooldown_timer -= delta
			if _cooldown_timer <= 0.0:
				if return_to_start_position and global_position.distance_to(_start_position) > 4.0:
					current_state = State.RETURNING
					_check_overlap_for_reaggro()
				else:
					current_state = State.IDLE
		State.RETURNING:
			var distance = global_position.distance_to(_start_position)
			if distance > 4.0:
				var direction = global_position.direction_to(_start_position)
				velocity = direction * return_speed
			else:
				global_position = _start_position
				velocity = Vector2.ZERO
				current_state = State.IDLE
		State.IDLE:
			velocity = velocity.move_toward(Vector2.ZERO, speed * 4 * delta)
		
	move_and_slide()

func _exit_tree() -> void:
	if GameManager:
		GameManager.unregister_pursuer(self)

func _check_overlap_for_reaggro() -> void:
	if lose_target_zone:
		for body in lose_target_zone.get_overlapping_bodies():
			if body.is_in_group("player"):
				_on_lose_target_entered(body)
				break

func _on_vision_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body as CharacterBody2D
		current_state = State.CHASE
		_cooldown_timer = 0.0
		if GameManager:
			GameManager.register_pursuer(self)

func _on_lose_target_entered(body: Node2D) -> void:
	if body.is_in_group("player") and (current_state == State.COOLDOWN or current_state == State.RETURNING):
		player = body as CharacterBody2D
		current_state = State.CHASE
		_cooldown_timer = 0.0
		if GameManager:
			GameManager.register_pursuer(self)

func _on_lose_target_exited(body: Node2D) -> void:
	if body == player:
		player = null
		if GameManager:
			GameManager.unregister_pursuer(self)
			
		if cooldown_duration > 0.0:
			current_state = State.COOLDOWN
			_cooldown_timer = cooldown_duration
		else:
			if return_to_start_position and global_position.distance_to(_start_position) > 4.0:
				current_state = State.RETURNING
			else:
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
