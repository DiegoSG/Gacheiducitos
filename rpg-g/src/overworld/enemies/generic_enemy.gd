extends CharacterBody2D

@export var speed: float = 70.0
@export var max_health: int = 3
@export var has_iframes: bool = true
@export var iframe_duration: float = 0.6
@export var cooldown_duration: float = 10.0
@export var return_to_start_position: bool = true
@export var return_speed: float = 70.0
@export var attack_damage: int = 1
## Intervalo (segundos) entre golpes de daño continuo del hitbox
@export var attack_rate: float = 0.6

@export_group("Estado alterado")
## Si es true, sus golpes pueden envenenar al jugador.
@export var is_poisonous: bool = false
@export_range(0, 100) var poison_chance: float = 100.0
@export var poison_status: StatusEffectData = preload("res://data/status_effects/poison.tres")

@export_group("Persistencia")
## Si tiene un valor asignado, su muerte se guarda en WorldStateManager y no vuelve a aparecer.
## Si está vacío (""), el estado solo dura mientras el jugador siga en este nivel (clave efímera).
@export var persistence_id: String = ""

var current_health: int = 3
var _persistence_key: String = ""

@onready var vision_zone: Area2D = get_node_or_null("VisionZone")
@onready var sprite: Sprite2D = $Sprite2D
@onready var lose_target_zone: Area2D = get_node_or_null("LoseTargetZone")
@onready var hitbox_component: HitboxComponent = $HitboxComponent
@onready var hurtbox_component: HurtboxComponent = $HurtboxComponent
@onready var loot_drop_component: LootDropComponent = get_node_or_null("LootDropComponent")

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

const CHASE_SOUND_INTERVAL: float = 0.4
var _chase_sound_timer: float = 0.0

func _ready() -> void:
	_persistence_key = PersistenceIdHelper.runtime_key(self, persistence_id)
	if _restore_state():
		return
		
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
		# Configuramos daño configurable y activamos el hitbox permanentemente con daño continuo
		hitbox_component.damage = attack_damage
		hitbox_component.continuous_damage = true
		hitbox_component.attack_rate = attack_rate
		hitbox_component.status_effect = poison_status if is_poisonous else null
		hitbox_component.status_chance = poison_chance if is_poisonous else 0.0
		hitbox_component.set_active(true)

func _physics_process(delta: float) -> void:
	if is_stunned:
		velocity = velocity.move_toward(Vector2.ZERO, speed * 15 * delta)
		move_and_slide()
		return
		
	match current_state:
		State.CHASE:
			if player != null and _is_player_in_attack_range():
				# Ya alcanza al jugador con su hitbox: se detiene ahí y sigue atacando
				velocity = Vector2.ZERO
			elif player != null:
				var direction: Vector2 = global_position.direction_to(player.global_position)
				velocity = direction * speed
				_chase_sound_timer -= delta
				if _chase_sound_timer <= 0.0:
					_chase_sound_timer = CHASE_SOUND_INTERVAL
					AudioManager.play_sfx(&"sfx_enemy_chase")
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
			var distance: float = global_position.distance_to(_start_position)
			if distance > 4.0:
				var direction: Vector2 = global_position.direction_to(_start_position)
				velocity = direction * return_speed
			else:
				global_position = _start_position
				velocity = Vector2.ZERO
				current_state = State.IDLE
		State.IDLE:
			velocity = velocity.move_toward(Vector2.ZERO, speed * 4 * delta)
		
	move_and_slide()

func _exit_tree() -> void:
	AlertSystem.unregister_pursuer(self)

## true si el hitbox ya solapa el hurtbox del jugador (punto desde el que puede golpearlo).
func _is_player_in_attack_range() -> bool:
	if hitbox_component == null:
		return false
	for area: Area2D in hitbox_component.get_overlapping_areas():
		if area is HurtboxComponent and area.get_parent() == player:
			return true
	return false

func _check_overlap_for_reaggro() -> void:
	if lose_target_zone:
		for body in lose_target_zone.get_overlapping_bodies():
			if body.is_in_group("player"):
				_on_lose_target_entered(body)
				break

func _on_vision_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if current_state != State.CHASE:
			AudioManager.play_sfx(&"sfx_enemy_detect")
		player = body as CharacterBody2D
		current_state = State.CHASE
		_cooldown_timer = 0.0
		AlertSystem.register_pursuer(self)

func _on_lose_target_entered(body: Node2D) -> void:
	if body.is_in_group("player") and (current_state == State.COOLDOWN or current_state == State.RETURNING):
		AudioManager.play_sfx(&"sfx_enemy_reacquire")
		player = body as CharacterBody2D
		current_state = State.CHASE
		_cooldown_timer = 0.0
		AlertSystem.register_pursuer(self)

func _on_lose_target_exited(body: Node2D) -> void:
	if body == player:
		AudioManager.play_sfx(&"sfx_enemy_lose_target")
		player = null
		AlertSystem.unregister_pursuer(self)
			
		if cooldown_duration > 0.0:
			current_state = State.COOLDOWN
			_cooldown_timer = cooldown_duration
		else:
			if return_to_start_position and global_position.distance_to(_start_position) > 4.0:
				current_state = State.RETURNING
			else:
				current_state = State.IDLE

func _on_hit_received(damage: int, attack_direction: Vector2, knockback_force: float) -> void:
	if is_invulnerable: return

	current_health -= damage

	# Componente físico del empujón
	velocity = attack_direction * knockback_force
	
	if current_health <= 0:
		AudioManager.play_sfx(&"sfx_enemy_death")
		_persist_death()
		if loot_drop_component:
			loot_drop_component.drop_loot()
		call_deferred("queue_free")
		return
		
	AudioManager.play_sfx(&"sfx_enemy_hurt")
	AudioManager.play_sfx(&"sfx_enemy_stunned")
	is_stunned = true
	get_tree().create_timer(0.3).timeout.connect(func() -> void: if is_inside_tree(): is_stunned = false)
	
	if has_iframes and iframe_duration > 0.0:
		is_invulnerable = true
		AudioManager.play_sfx(&"sfx_enemy_invulnerable")
		
		# Efecto visual de parpadeo temporal (0.2s por loop completo)
		var blink_time: float = 0.1
		var loops: int = int(max(1.0, iframe_duration / (blink_time * 2)))

		var tween: Tween = create_tween()
		tween.set_loops(loops)
		tween.tween_property(sprite, "modulate:a", 0.2, blink_time)
		tween.tween_property(sprite, "modulate:a", 1.0, blink_time)

		get_tree().create_timer(iframe_duration).timeout.connect(func() -> void: if is_inside_tree(): is_invulnerable = false)

func _restore_state() -> bool:
	if _persistence_key.is_empty():
		return false
	if WorldStateManager.has_state(_persistence_key):
		var data: Dictionary = WorldStateManager.load_state(_persistence_key)
		if data.get("is_dead", false):
			queue_free()
			return true
	return false

func _persist_death() -> void:
	if _persistence_key.is_empty():
		return
	WorldStateManager.save_state(_persistence_key, {"is_dead": true})
