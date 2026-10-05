extends CharacterBody2D

@export var speed: float = 350.0
var knockback_velocity: Vector2 = Vector2.ZERO
var is_stunned: bool = false
var is_invulnerable: bool = false
var is_dead: bool = false
@onready var actionable_finder: Area2D = $ActionableFinder
@onready var hitbox_component: HitboxComponent = $HitboxComponent
@onready var hurtbox_component: HurtboxComponent = $HurtboxComponent
@onready var sprite: Sprite2D = $Sprite2D
@onready var slash_sprite: Sprite2D = get_node_or_null("HitboxComponent/SlashSprite")
## Escudo PROXY: bloqueo total en 360° mientras se mantiene "block" (ver shield_component.gd).
@onready var shield_component: ShieldComponent = $ShieldComponent

# Texturas canónicas para las 8 orientaciones (usando simetría horizontal flip_h)
const TEX_DOWN = preload("res://assets/sprites/player_down.png")           # Sur (Frente)
const TEX_DOWN_SIDE = preload("res://assets/sprites/player_down_side.png") # Sur-Este / Sur-Oeste (Diagonal frente)
const TEX_SIDE = preload("res://assets/sprites/player_side.png")           # Este / Oeste (Perfil lateral)
const TEX_UP_SIDE = preload("res://assets/sprites/player_up_side.png")     # Norte-Este / Norte-Oeste (Diagonal espalda)
const TEX_UP = preload("res://assets/sprites/player_up.png")               # Norte (Espalda)

var is_dialogue_active: bool = false
var is_attacking: bool = false
var last_direction: Vector2 = Vector2.DOWN

const STEP_SOUND_INTERVAL: float = 0.3
var _step_timer: float = 0.0

func _ready() -> void:
	add_to_group("player")
	
	if slash_sprite:
		slash_sprite.visible = false
	
	_update_sprite_facing(last_direction)
	shield_component.set_facing(last_direction)
	
	if hurtbox_component:
		hurtbox_component.hit_received.connect(_on_hit_received)
		hurtbox_component.status_inflicted.connect(_on_status_inflicted)
		
	if not PlayerStats.player_died.is_connected(_on_player_died):
		PlayerStats.player_died.connect(_on_player_died)
			
	if not CheckpointManager.player_respawned.is_connected(_on_player_respawned):
		CheckpointManager.player_respawned.connect(_on_player_respawned)
	
	# Conectarse a las señales de Dialogue Manager
	if not DialogueManager.dialogue_started.is_connected(_on_dialogue_started):
		DialogueManager.dialogue_started.connect(_on_dialogue_started)
	if not DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

func _exit_tree() -> void:
	if DialogueManager.dialogue_started.is_connected(_on_dialogue_started):
		DialogueManager.dialogue_started.disconnect(_on_dialogue_started)
	if DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.disconnect(_on_dialogue_ended)

func _on_dialogue_started(_resource: DialogueResource) -> void:
	is_dialogue_active = true
	velocity = Vector2.ZERO # Detenemos al jugador inmediatamente

func _on_dialogue_ended(_resource: DialogueResource) -> void:
	# Damos un pequeñísimo delay para no atrapar el mismo input que cerró el diálogo
	var tree: SceneTree = get_tree()
	if not tree:
		is_dialogue_active = false
		return
	await tree.create_timer(0.1).timeout
	if not is_inside_tree():
		return
	is_dialogue_active = false

func _physics_process(delta: float) -> void:
	if is_dialogue_active or is_dead:
		shield_component.set_blocking(false)
		return
		
	if is_stunned:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 1000 * delta)
		move_and_slide()
		return
		
	# Get input direction
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_update_blocking()
	
	if direction != Vector2.ZERO:
		last_direction = direction
		# Rotate the interaction area and hitbox to face movement direction
		actionable_finder.rotation = direction.angle() - PI/2
		hitbox_component.rotation = direction.angle() - PI/2
		
		# Actualizar las 8 orientaciones visuales del jugador
		_update_sprite_facing(direction)
		shield_component.set_facing(direction)
		if shield_component.is_blocking:
			# Con el escudo arriba solo se puede girar, no desplazarse
			velocity = Vector2.ZERO
			_step_timer = 0.0
		else:
			velocity = direction * speed * PlayerStats.get_speed_multiplier()
			_step_timer -= delta
			if _step_timer <= 0.0 and not is_attacking:
				_step_timer = STEP_SOUND_INTERVAL
				AudioManager.play_sfx(&"sfx_player_step")
	else:
		velocity = Vector2.ZERO
		_step_timer = 0.0

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
	if is_dead:
		return
	# Escudo PROXY: un golpe bloqueado no hace daño, ni knockback, ni activa i-frames
	if shield_component.try_block(damage, attack_direction):
		return
	
	var tree: SceneTree = get_tree()
	
	# Aplicar siempre knockback físico hacia atrás
	if knockback_force > 0:
		is_stunned = true
		knockback_velocity = attack_direction * knockback_force
		AudioManager.play_sfx(&"sfx_player_knockback")
		if tree:
			tree.create_timer(0.3).timeout.connect(func() -> void:
				if is_inside_tree() and not is_dead:
					is_stunned = false
			)
		else:
			is_stunned = false


	# Si ya está invencible, no resta vida ni reinicia el temporizador de i-frames
	if is_invulnerable:
		return
	
	PlayerStats.take_damage(damage)
	
	if is_dead:
		return
		
	is_invulnerable = true
	AudioManager.play_sfx(&"sfx_player_hurt")
	AudioManager.play_sfx(&"sfx_player_invulnerable")
	
	# Efecto de I-frames visuales (parpadeo de 1 segundo)
	var tween: Tween = create_tween()
	tween.set_loops(5) # 5 parpadeos de 0.2s c/u = 1 seg de i-frames
	tween.tween_property(sprite, "modulate:a", 0.2, 0.1)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.1)
	
	if tree:
		tree.create_timer(1.0).timeout.connect(func() -> void:
			if is_inside_tree():
				is_invulnerable = false
		)
	else:
		is_invulnerable = false

## Un golpe inflige un estado alterado: se ignora si esta muerto, invulnerable o bloqueando (igual que el dano).
func _on_status_inflicted(effect: StatusEffectData) -> void:
	if is_dead or is_invulnerable or shield_component.is_blocking:
		return
	PlayerStats.apply_status(effect)

func _on_player_died() -> void:
	if is_dead:
		return
	is_dead = true
	AudioManager.play_sfx(&"sfx_player_death")
	AudioManager.play_music(&"music_death")
	is_stunned = false
	is_invulnerable = true
	velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	
	if hitbox_component:
		hitbox_component.set_active(false)
	if hurtbox_component:
		hurtbox_component.set_deferred("monitoring", false)
		hurtbox_component.set_deferred("monitorable", false)
		
	# Feedback visual de muerte (fade/rotación suave)
	if sprite:
		var death_tween: Tween = create_tween()
		death_tween.tween_property(sprite, "rotation_degrees", 90.0, 0.25)
		death_tween.parallel().tween_property(sprite, "modulate", Color(0.8, 0.2, 0.2, 0.8), 0.25)

	# Breve pausa para notar la caída antes del fader de respawn
	var tree: SceneTree = get_tree()
	if tree:
		await tree.create_timer(0.5).timeout
	CheckpointManager.respawn_player()

func _on_player_respawned() -> void:
	AudioManager.play_sfx(&"sfx_player_respawn")
	is_dead = false
	shield_component.reset()
	is_invulnerable = false
	is_stunned = false
	velocity = Vector2.ZERO
	if sprite:
		sprite.rotation_degrees = 0.0
		sprite.modulate = Color.WHITE
	if hurtbox_component:
		hurtbox_component.set_deferred("monitoring", true)
		hurtbox_component.set_deferred("monitorable", true)


func _update_blocking() -> void:
	shield_component.set_blocking(Input.is_action_pressed("block") and not is_attacking)

func attack() -> void:
	if is_attacking or shield_component.is_blocking:
		return
	is_attacking = true
	AudioManager.play_sfx(&"sfx_player_attack")
	
	# Visual sword slash animation & feedback
	if slash_sprite:
		slash_sprite.visible = true
		slash_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		slash_sprite.scale = Vector2(0.06, 0.06)
		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(slash_sprite, "scale", Vector2(0.13, 0.13), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(slash_sprite, "modulate:a", 0.0, 0.15)
	
	# Slight lunge of the player sprite
	if sprite:
		var original_pos: Vector2 = Vector2.ZERO
		var lunge_offset: Vector2 = last_direction.normalized() * 6.0
		var lunge_tween: Tween = create_tween()
		lunge_tween.tween_property(sprite, "position", lunge_offset, 0.06)
		lunge_tween.tween_property(sprite, "position", original_pos, 0.09)
		
	# El dano del ataque depende de la fuerza efectiva (base + estados)
	hitbox_component.damage = PlayerStats.get_strength()
	# Activar hitbox por un instante
	hitbox_component.set_active(true)
	var tree: SceneTree = get_tree()
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
	if is_dialogue_active or is_dead:
		shield_component.set_blocking(false)
		return
		
	if event.is_action_pressed("interact"):
		var actionables: Array[Area2D] = actionable_finder.get_overlapping_areas()
		var interacted: bool = false
		for area in actionables:
			if area.has_method("action"):
				interacted = true
				AudioManager.play_ui(&"sfx_player_interact")
				get_viewport().set_input_as_handled()
				area.action()
				break
		if not interacted:
			AudioManager.play_sfx(&"sfx_player_interact_none")

	if event.is_action_pressed("attack"):
		attack()
		get_viewport().set_input_as_handled()
