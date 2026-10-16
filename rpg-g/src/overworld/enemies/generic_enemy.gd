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

@export_group("Esquive de obstáculos")
## Si es true, rodea paredes y obstáculos en vez de quedarse pegado contra ellos.
@export var avoid_obstacles: bool = true
## Distancia (px) que mira hacia adelante para detectar si el camino está bloqueado.
@export var avoidance_lookahead: float = 24.0

@export_group("Al ser derrotado")
## Acciones que se ejecutan al morir, con el enemigo como nodo ejecutor (ej. DropLootAction).
## Corren antes de borrar al enemigo: usar acciones instantáneas (sin esperas).
@export var on_defeat_actions: Array[ActionResource] = []

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
## Si en el frame anterior ya alcanzaba al jugador (para avisar una sola vez al entrar en rango).
var _was_in_attack_range: bool = false

# Seguimiento de paredes: al chocar, bordea el obstáculo pegado a él (siempre por el mismo lado)
# hasta tener el camino libre y estar más cerca del objetivo que cuando chocó. Así sale también
# de esquinas y bolsillos en "U" sin necesitar navegación en el nivel.
## Grados entre cada dirección que prueba al buscar un hueco.
const WALL_FOLLOW_STEP_DEGREES: float = 30.0
## Tiempo máximo bordeando un mismo obstáculo antes de reintentar desde cero (el objetivo puede moverse).
const WALL_FOLLOW_MAX_TIME: float = 6.0
## Si apenas avanza durante este tiempo queriendo moverse, prueba a bordear por el otro lado.
const STUCK_TIME: float = 0.5
var _is_following_wall: bool = false
## -1 o 1: lado hacia el que gira para alejarse de la pared que bordea.
var _follow_side: int = 1
var _follow_heading: Vector2 = Vector2.ZERO
var _follow_hit_distance: float = 0.0
var _follow_timer: float = 0.0
var _follow_state: State = State.IDLE
var _stuck_timer: float = 0.0

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
		
	if current_state != State.CHASE:
		_was_in_attack_range = false
	match current_state:
		State.CHASE:
			var in_range: bool = player != null and _is_player_in_attack_range()
			if in_range and not _was_in_attack_range:
				AudioManager.play_sfx_at(&"sfx_enemy_attack_windup", global_position)
			_was_in_attack_range = in_range
			if in_range:
				# Ya alcanza al jugador con su hitbox: se detiene ahí y sigue atacando
				velocity = Vector2.ZERO
			elif player != null:
				velocity = _steer(player.global_position, delta) * speed
				_chase_sound_timer -= delta
				if _chase_sound_timer <= 0.0:
					_chase_sound_timer = CHASE_SOUND_INTERVAL
					AudioManager.play_sfx_at(&"sfx_enemy_chase", global_position)
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
				velocity = _steer(_start_position, delta) * return_speed
			else:
				global_position = _start_position
				velocity = Vector2.ZERO
				current_state = State.IDLE
		State.IDLE:
			velocity = velocity.move_toward(Vector2.ZERO, speed * 4 * delta)
		
	var previous_position: Vector2 = global_position
	move_and_slide()
	_update_stuck(previous_position, delta)

## Devuelve la dirección (normalizada) para ir hacia `target`, bordeando obstáculos si hace falta.
func _steer(target: Vector2, delta: float) -> Vector2:
	var desired: Vector2 = global_position.direction_to(target)
	if not avoid_obstacles or desired == Vector2.ZERO:
		return desired
	if _follow_state != current_state:
		_follow_state = current_state
		_is_following_wall = false

	var distance: float = global_position.distance_to(target)
	var direct_blocking: KinematicCollision2D = _probe(desired)

	if _is_following_wall:
		_follow_timer += delta
		var got_closer: bool = distance < _follow_hit_distance - 1.0
		if direct_blocking == null and (got_closer or _follow_timer >= WALL_FOLLOW_MAX_TIME):
			_is_following_wall = false
		elif _follow_timer >= WALL_FOLLOW_MAX_TIME:
			_start_wall_follow(desired, direct_blocking, distance)
	elif direct_blocking != null:
		_start_wall_follow(desired, direct_blocking, distance)

	if not _is_following_wall:
		return desired

	# Si ya no tiene la pared al costado (pasó una esquina), gira hacia ella para doblarla;
	# después se aleja de a poco de la pared hasta encontrar hueco.
	var first: Vector2 = _follow_heading
	var toward_wall: Vector2 = _follow_heading.rotated(deg_to_rad(-90.0) * _follow_side)
	if _probe(toward_wall) == null:
		first = _follow_heading.rotated(deg_to_rad(-WALL_FOLLOW_STEP_DEGREES) * _follow_side)
	var steps: int = int(360.0 / WALL_FOLLOW_STEP_DEGREES)
	for step: int in range(steps):
		var candidate: Vector2 = first.rotated(deg_to_rad(WALL_FOLLOW_STEP_DEGREES * step) * _follow_side)
		if _probe(candidate) == null:
			_follow_heading = candidate
			return candidate
	# Rodeado por todos lados: deja que move_and_slide deslice lo que pueda.
	return desired

func _start_wall_follow(desired: Vector2, blocking: KinematicCollision2D, distance: float) -> void:
	_is_following_wall = true
	_follow_timer = 0.0
	_follow_hit_distance = distance
	# Bordea en el sentido de la pared que más se parezca a la dirección deseada.
	var tangent: Vector2 = desired.orthogonal()
	if blocking:
		tangent = blocking.get_normal().orthogonal()
		if tangent.dot(desired) < 0.0:
			tangent = -tangent
	_follow_heading = tangent
	_follow_side = 1 if desired.cross(tangent) >= 0.0 else -1

## Colisión que encontraría al avanzar `avoidance_lookahead` px en `direction` (null si está libre).
func _probe(direction: Vector2) -> KinematicCollision2D:
	return move_and_collide(direction * avoidance_lookahead, true)

## Si quiere moverse pero casi no avanza (atascado en una esquina), bordea por el otro lado.
func _update_stuck(previous_position: Vector2, delta: float) -> void:
	var is_travelling: bool = current_state == State.CHASE or current_state == State.RETURNING
	if not avoid_obstacles or not is_travelling or not _is_following_wall or velocity.length() < 1.0:
		_stuck_timer = 0.0
		return
	var expected: float = velocity.length() * delta
	if global_position.distance_to(previous_position) < expected * 0.25:
		_stuck_timer += delta
		if _stuck_timer >= STUCK_TIME:
			_stuck_timer = 0.0
			_follow_side = -_follow_side
			_follow_heading = -_follow_heading
			_follow_timer = 0.0
	else:
		_stuck_timer = 0.0

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
			AudioManager.play_sfx_at(&"sfx_enemy_detect", global_position)
		player = body as CharacterBody2D
		current_state = State.CHASE
		_cooldown_timer = 0.0
		AlertSystem.register_pursuer(self)

func _on_lose_target_entered(body: Node2D) -> void:
	if body.is_in_group("player") and (current_state == State.COOLDOWN or current_state == State.RETURNING):
		AudioManager.play_sfx_at(&"sfx_enemy_reacquire", global_position)
		player = body as CharacterBody2D
		current_state = State.CHASE
		_cooldown_timer = 0.0
		AlertSystem.register_pursuer(self)

func _on_lose_target_exited(body: Node2D) -> void:
	if body == player:
		AudioManager.play_sfx_at(&"sfx_enemy_lose_target", global_position)
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
		AudioManager.play_sfx_at(&"sfx_enemy_death", global_position)
		_persist_death()
		ActionRunner.run(on_defeat_actions, self)
		call_deferred("queue_free")
		return
		
	AudioManager.play_sfx_at(&"sfx_enemy_hurt", global_position)
	is_stunned = true
	get_tree().create_timer(0.3).timeout.connect(func() -> void: if is_inside_tree(): is_stunned = false)
	
	if has_iframes and iframe_duration > 0.0:
		is_invulnerable = true
		AudioManager.play_sfx_at(&"sfx_enemy_invulnerable", global_position)
		
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
