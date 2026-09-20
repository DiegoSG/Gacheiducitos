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
@onready var sprite: Sprite2D = $Sprite2D
@onready var slash_sprite: Sprite2D = get_node_or_null("HitboxComponent/SlashSprite")

# Texturas canónicas para las 8 orientaciones (usando simetría horizontal flip_h)
const TEX_DOWN = preload("res://assets/sprites/player_down.png")           # Sur (Frente)
const TEX_DOWN_SIDE = preload("res://assets/sprites/player_down_side.png") # Sur-Este / Sur-Oeste (Diagonal frente)
const TEX_SIDE = preload("res://assets/sprites/player_side.png")           # Este / Oeste (Perfil lateral)
const TEX_UP_SIDE = preload("res://assets/sprites/player_up_side.png")     # Norte-Este / Norte-Oeste (Diagonal espalda)
const TEX_UP = preload("res://assets/sprites/player_up.png")               # Norte (Espalda)

var is_dialogue_active: bool = false
var is_attacking: bool = false
var last_direction: Vector2 = Vector2.DOWN

func _ready() -> void:
	add_to_group("player")
	current_health = max_health
	
	if slash_sprite:
		slash_sprite.visible = false
	
	_update_sprite_facing(last_direction)
	
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
		
		# Actualizar las 8 orientaciones visuales del jugador
		_update_sprite_facing(direction)
	else:
		velocity = Vector2.ZERO

	if is_attacking:
		velocity = Vector2.ZERO # Stop moving while attacking

	move_and_slide()

## Configura la textura y el flip horizontal para las 8 rotaciones posibles
func _update_sprite_facing(dir: Vector2) -> void:
	if not sprite or dir == Vector2.ZERO:
		return
		
	# Ángulo normalizado en grados [0, 360)
	# 0° = Derecha (Este), 90° = Abajo (Sur), 180° = Izquierda (Oeste), 270° = Arriba (Norte)
	var deg: float = fposmod(rad_to_deg(dir.angle()), 360.0)
	
	# Segmentación de 8 sectores de 45° con centro en los ejes
	# [337.5 a 22.5]   -> Este (Perfil derecho)
	# [22.5 a 67.5]    -> Sur-Este (Diagonal frente derecha)
	# [67.5 a 112.5]   -> Sur (Frente)
	# [112.5 a 157.5]  -> Sur-Oeste (Diagonal frente izquierda)
	# [157.5 a 202.5]  -> Oeste (Perfil izquierdo)
	# [202.5 a 247.5]  -> Norte-Oeste (Diagonal espalda izquierda)
	# [247.5 a 292.5]  -> Norte (Espalda)
	# [292.5 a 337.5]  -> Norte-Este (Diagonal espalda derecha)
	
	if deg >= 337.5 or deg < 22.5: # ESTE
		sprite.texture = TEX_SIDE
		sprite.flip_h = false
	elif deg >= 22.5 and deg < 67.5: # SUR-ESTE
		sprite.texture = TEX_DOWN_SIDE
		sprite.flip_h = false
	elif deg >= 67.5 and deg < 112.5: # SUR (FRENTE)
		sprite.texture = TEX_DOWN
		sprite.flip_h = false
	elif deg >= 112.5 and deg < 157.5: # SUR-OESTE
		sprite.texture = TEX_DOWN_SIDE
		sprite.flip_h = true
	elif deg >= 157.5 and deg < 202.5: # OESTE
		sprite.texture = TEX_SIDE
		sprite.flip_h = true
	elif deg >= 202.5 and deg < 247.5: # NORTE-OESTE
		sprite.texture = TEX_UP_SIDE
		sprite.flip_h = true
	elif deg >= 247.5 and deg < 292.5: # NORTE (ESPALDA)
		sprite.texture = TEX_UP
		sprite.flip_h = false
	else: # NORTE-ESTE [292.5 a 337.5]
		sprite.texture = TEX_UP_SIDE
		sprite.flip_h = false

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
	
	# Visual sword slash animation & feedback
	if slash_sprite:
		slash_sprite.visible = true
		slash_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		slash_sprite.scale = Vector2(0.06, 0.06)
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(slash_sprite, "scale", Vector2(0.13, 0.13), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(slash_sprite, "modulate:a", 0.0, 0.15)
	
	# Slight lunge of the player sprite
	if sprite:
		var original_pos = Vector2.ZERO
		var lunge_offset = last_direction.normalized() * 6.0
		var lunge_tween = create_tween()
		lunge_tween.tween_property(sprite, "position", lunge_offset, 0.06)
		lunge_tween.tween_property(sprite, "position", original_pos, 0.09)
		
	# Activar hitbox por un instante
	hitbox_component.set_active(true)
	var tree = get_tree()
	if tree:
		await tree.create_timer(0.18).timeout
	if not is_inside_tree():
		return
	hitbox_component.set_active(false)
	if slash_sprite:
		slash_sprite.visible = false
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

	if event.is_action_pressed("attack"):
		attack()
		get_viewport().set_input_as_handled()
