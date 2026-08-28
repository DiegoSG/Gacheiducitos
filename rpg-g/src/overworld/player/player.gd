extends CharacterBody2D

@export var speed: float = 350.0
@export var max_health: int = 3
var current_health: int = 3
var knockback_velocity: Vector2 = Vector2.ZERO
var is_stunned: bool = false
var is_invulnerable: bool = false
@onready var actionable_finder: Area2D = $ActionableFinder
@onready var hitbox_component: HitboxComponent = $HitboxComponent
@onready var hurtbox_component: HurtboxComponent = $HurtboxComponent

var is_dialogue_active: bool = false
var is_attacking: bool = false
var last_direction: Vector2 = Vector2.DOWN

func _ready() -> void:
	add_to_group("player")
	current_health = max_health
	
	if hurtbox_component:
		hurtbox_component.hit_received.connect(_on_hit_received)
	
	# Conectarse a las señales de Dialogue Manager
	var dm = Engine.get_singleton("DialogueManager")
	if dm:
		if not dm.dialogue_started.is_connected(_on_dialogue_started):
			dm.dialogue_started.connect(_on_dialogue_started)
		if not dm.dialogue_ended.is_connected(_on_dialogue_ended):
			dm.dialogue_ended.connect(_on_dialogue_ended)

func _exit_tree() -> void:
	var dm = Engine.get_singleton("DialogueManager")
	if dm:
		if dm.dialogue_started.is_connected(_on_dialogue_started):
			dm.dialogue_started.disconnect(_on_dialogue_started)
		if dm.dialogue_ended.is_connected(_on_dialogue_ended):
			dm.dialogue_ended.disconnect(_on_dialogue_ended)

func _on_dialogue_started(_resource: DialogueResource) -> void:
	is_dialogue_active = true
	velocity = Vector2.ZERO # Detenemos al jugador inmediatamente

func _on_dialogue_ended(_resource: DialogueResource) -> void:
	# Damos un pequeñísimo delay para no atrapar el mismo input que cerró el diálogo
	var tree = get_tree()
	if not tree:
		is_dialogue_active = false
		return
	await tree.create_timer(0.1).timeout
	if not is_inside_tree():
		return
	is_dialogue_active = false

func _physics_process(delta: float) -> void:
	if is_dialogue_active:
		return
		
	if is_stunned:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 1000 * delta)
		move_and_slide()
		return
		
	# Get input direction
	var direction: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if direction != Vector2.ZERO:
		velocity = direction * speed
		last_direction = direction
		# Rotate the interaction area and hitbox to face movement direction
		actionable_finder.rotation = direction.angle() - PI/2
		hitbox_component.rotation = direction.angle() - PI/2
	else:
		velocity = Vector2.ZERO

	if is_attacking:
		velocity = Vector2.ZERO # Stop moving while attacking

	move_and_slide()

func _on_hit_received(damage: int, attack_direction: Vector2, knockback_force: float) -> void:
	if is_invulnerable:
		return
	
	current_health -= damage
	print("Player hit! Health: ", current_health)
	
	is_invulnerable = true
	
	# Efecto de I-frames visuales (parpadeo)
	var tween = create_tween()
	tween.set_loops(5) # 5 parpadeos de 0.2s c/u = 1 seg de i-frames
	tween.tween_property($Sprite2D, "modulate:a", 0.2, 0.1)
	tween.tween_property($Sprite2D, "modulate:a", 1.0, 0.1)
	
	var tree = get_tree()
	if not tree:
		is_invulnerable = false
		is_stunned = false
		return
		
	if knockback_force > 0:
		is_stunned = true
		knockback_velocity = attack_direction * knockback_force
		await tree.create_timer(0.3).timeout
		if not is_inside_tree():
			return
		is_stunned = false
		await tree.create_timer(0.7).timeout
		if not is_inside_tree():
			return
		is_invulnerable = false
	else:
		await tree.create_timer(1.0).timeout
		if not is_inside_tree():
			return
		is_invulnerable = false

func attack() -> void:
	if is_attacking:
		return
	is_attacking = true
	# Activar hitbox por un instante
	hitbox_component.set_active(true)
	var tree = get_tree()
	if tree:
		await tree.create_timer(0.2).timeout
	if not is_inside_tree():
		return
	hitbox_component.set_active(false)
	is_attacking = false

# Trasladamos la interacción a _unhandled_input para respetar los CanvasLayer (UI)
func _unhandled_input(event: InputEvent) -> void:
	if is_dialogue_active:
		return
		
	if event.is_action_pressed("ui_accept"):
		var actionables = actionable_finder.get_overlapping_areas()
		for area in actionables:
			if area.has_method("action"):
				get_viewport().set_input_as_handled()
				area.action()
				break

	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_Z:
			attack()
