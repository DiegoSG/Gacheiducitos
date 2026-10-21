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
## Equipped shield: blocks according to its ShieldData while "block" is held (see shield_component.gd).
@onready var shield_component: ShieldComponent = $ShieldComponent
## Active weapon: hit damage, reach and cooldown (see weapon_component.gd).
@onready var weapon_component: WeaponComponent = $WeaponComponent

# Canonical textures for the 8 orientations (using horizontal flip_h symmetry)
const TEX_DOWN = preload("res://assets/sprites/player_down.png")           # South (Front)
const TEX_DOWN_SIDE = preload("res://assets/sprites/player_down_side.png") # South-East / South-West (front diagonal)
const TEX_SIDE = preload("res://assets/sprites/player_side.png")           # East / West (side profile)
const TEX_UP_SIDE = preload("res://assets/sprites/player_up_side.png")     # North-East / North-West (back diagonal)
const TEX_UP = preload("res://assets/sprites/player_up.png")               # North (Back)

var is_dialogue_active: bool = false
var is_attacking: bool = false
var last_direction: Vector2 = Vector2.DOWN
## From the last hit received: whether the shield covered it and whether it arrived outside the i-frames.
## They decide whether the status carried by the same hit (status_inflicted arrives right after) is applied.
var _last_hit_shielded: bool = false
var _last_hit_outside_iframes: bool = false

const STEP_SOUND_INTERVAL: float = 0.3
var _step_timer: float = 0.0

func _ready() -> void:
	add_to_group("player")
	
	_update_sprite_facing(last_direction)
	shield_component.set_facing(last_direction)
	
	# Equipment lives in Inventory; the player only passes it to its components
	Inventory.equipment_changed.connect(_on_equipment_changed)
	Inventory.active_weapon_changed.connect(_on_active_weapon_changed)
	_refresh_equipment()
	
	if hurtbox_component:
		hurtbox_component.hit_received.connect(_on_hit_received)
		hurtbox_component.status_inflicted.connect(_on_status_inflicted)
		
	if not PlayerStats.player_died.is_connected(_on_player_died):
		PlayerStats.player_died.connect(_on_player_died)
			
	if not CheckpointManager.player_respawned.is_connected(_on_player_respawned):
		CheckpointManager.player_respawned.connect(_on_player_respawned)
	
	# Connect to the Dialogue Manager signals
	if not DialogueManager.dialogue_started.is_connected(_on_dialogue_started):
		DialogueManager.dialogue_started.connect(_on_dialogue_started)
	if not DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

func _exit_tree() -> void:
	if Inventory.equipment_changed.is_connected(_on_equipment_changed):
		Inventory.equipment_changed.disconnect(_on_equipment_changed)
	if Inventory.active_weapon_changed.is_connected(_on_active_weapon_changed):
		Inventory.active_weapon_changed.disconnect(_on_active_weapon_changed)
	if DialogueManager.dialogue_started.is_connected(_on_dialogue_started):
		DialogueManager.dialogue_started.disconnect(_on_dialogue_started)
	if DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.disconnect(_on_dialogue_ended)

func _on_dialogue_started(_resource: DialogueResource) -> void:
	is_dialogue_active = true
	velocity = Vector2.ZERO # Stop the player immediately

func _on_dialogue_ended(_resource: DialogueResource) -> void:
	# A very small delay so we don't catch the same input that closed the dialogue
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
		
		# Update the player's 8 visual orientations
		_update_sprite_facing(direction)
		shield_component.set_facing(direction)
		var shield_multiplier: float = shield_component.get_speed_multiplier()
		if shield_multiplier <= 0.0:
			# With the shield raised you can only turn, not move
			velocity = Vector2.ZERO
			_step_timer = 0.0
		else:
			velocity = direction * speed * PlayerStats.get_speed_multiplier() * shield_multiplier
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

## Sets the texture and horizontal flip for the 8 possible rotations
## Faces the player without moving it (for example, during the automatic walk when leaving a portal).
func face_direction(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	last_direction = direction.normalized()
	_update_sprite_facing(last_direction)
	shield_component.set_facing(last_direction)

func _update_sprite_facing(dir: Vector2) -> void:
	if not sprite or dir == Vector2.ZERO:
		return
		
	# Normalized angle in degrees [0, 360)
	# 0° = Right (East), 90° = Down (South), 180° = Left (West), 270° = Up (North)
	var deg: float = fposmod(rad_to_deg(dir.angle()), 360.0)

	# Segmentation into 8 sectors of 45° centered on the axes
	# [337.5 to 22.5]   -> East (right profile)
	# [22.5 to 67.5]    -> South-East (right front diagonal)
	# [67.5 to 112.5]   -> South (Front)
	# [112.5 to 157.5]  -> South-West (left front diagonal)
	# [157.5 to 202.5]  -> West (left profile)
	# [202.5 to 247.5]  -> North-West (left back diagonal)
	# [247.5 to 292.5]  -> North (Back)
	# [292.5 to 337.5]  -> North-East (right back diagonal)

	if deg >= 337.5 or deg < 22.5: # EAST
		sprite.texture = TEX_SIDE
		sprite.flip_h = false
	elif deg >= 22.5 and deg < 67.5: # SOUTH-EAST
		sprite.texture = TEX_DOWN_SIDE
		sprite.flip_h = false
	elif deg >= 67.5 and deg < 112.5: # SOUTH (FRONT)
		sprite.texture = TEX_DOWN
		sprite.flip_h = false
	elif deg >= 112.5 and deg < 157.5: # SOUTH-WEST
		sprite.texture = TEX_DOWN_SIDE
		sprite.flip_h = true
	elif deg >= 157.5 and deg < 202.5: # WEST
		sprite.texture = TEX_SIDE
		sprite.flip_h = true
	elif deg >= 202.5 and deg < 247.5: # NORTH-WEST
		sprite.texture = TEX_UP_SIDE
		sprite.flip_h = true
	elif deg >= 247.5 and deg < 292.5: # NORTH (BACK)
		sprite.texture = TEX_UP
		sprite.flip_h = false
	else: # NORTH-EAST [292.5 to 337.5]
		sprite.texture = TEX_UP_SIDE
		sprite.flip_h = false

func _on_hit_received(damage: int, attack_direction: Vector2, knockback_force: float) -> void:
	if is_dead:
		return
	_last_hit_outside_iframes = not is_invulnerable
	
	var tree: SceneTree = get_tree()
	
	# Always apply physical knockback backwards (also with the shield: the enemy pushes you)
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

	# Shield: a covered hit loses part of its damage; if nothing is left, it does not activate i-frames (knockback was already applied)
	_last_hit_shielded = shield_component.covers_hit(attack_direction)
	if _last_hit_shielded:
		damage = shield_component.absorb(damage)
		if damage <= 0:
			AudioManager.play_sfx(&"sfx_player_block_hit")
			return

	# If already invulnerable, it does not subtract health or restart the i-frame timer
	if is_invulnerable:
		return
	
	PlayerStats.take_damage(damage)
	
	if is_dead:
		return
		
	is_invulnerable = true
	AudioManager.play_sfx(&"sfx_player_hurt")
	
	# Visual I-frames effect (1-second blink)
	var tween: Tween = create_tween()
	tween.set_loops(5) # 5 blinks of 0.2s each = 1 sec of i-frames
	tween.tween_property(sprite, "modulate:a", 0.2, 0.1)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.1)
	
	if tree:
		tree.create_timer(1.0).timeout.connect(func() -> void:
			if is_inside_tree():
				is_invulnerable = false
		)
	else:
		is_invulnerable = false

## A hit inflicts a status effect: it is ignored if dead, if the hit arrived during the i-frames
## or if the shield covered it and stops that status.
func _on_status_inflicted(effect: StatusEffectData) -> void:
	if is_dead or not _last_hit_outside_iframes:
		return
	if _last_hit_shielded and shield_component.blocks_status(effect.id):
		return
	AudioManager.play_sfx(&"sfx_status_inflicted")
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
	
	weapon_component.cancel()
	if hurtbox_component:
		hurtbox_component.set_deferred("monitoring", false)
		hurtbox_component.set_deferred("monitorable", false)
		
	# Visual death feedback (smooth fade/rotation)
	if sprite:
		var death_tween: Tween = create_tween()
		death_tween.tween_property(sprite, "rotation_degrees", 90.0, 0.25)
		death_tween.parallel().tween_property(sprite, "modulate", Color(0.8, 0.2, 0.2, 0.8), 0.25)

	# Brief pause to notice the fall before the respawn fader
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
	if is_attacking or shield_component.is_blocking or not weapon_component.can_attack():
		return
	is_attacking = true
	AudioManager.play_sfx(&"sfx_player_attack")
	
	# Slight lunge of the player sprite
	if sprite:
		var original_pos: Vector2 = Vector2.ZERO
		var lunge_offset: Vector2 = last_direction.normalized() * 6.0
		var lunge_tween: Tween = create_tween()
		lunge_tween.tween_property(sprite, "position", lunge_offset, 0.06)
		lunge_tween.tween_property(sprite, "position", original_pos, 0.09)
		
	# The hit's damage is the effective strength (base + statuses) + the active weapon's damage
	await weapon_component.attack(PlayerStats.get_strength())
	if not is_inside_tree():
		return
	is_attacking = false

func _on_equipment_changed(_slot: String, _item_id: String) -> void:
	_refresh_equipment()

func _on_active_weapon_changed(_slot: String) -> void:
	_refresh_equipment()

func _refresh_equipment() -> void:
	weapon_component.set_weapon(Inventory.get_active_melee())
	shield_component.shield_data = Inventory.get_equipped_shield()

# Interaction is handled in _unhandled_input so CanvasLayer (UI) is respected
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
