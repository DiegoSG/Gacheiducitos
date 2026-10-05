extends Area2D
class_name MG_RunnerPlayer

signal died

enum State { RUNNING, JUMPING, DUCKING }
var state: State = State.RUNNING

const GROUND_Y: float = 820.0
const BULLET_SCENE: PackedScene = preload("res://src/minigames/mg_runner/mg_runner_bullet.tscn")

# Parámetros físicos configurables en Inspector
@export var jump_velocity: float = -1050.0
@export var jump_gravity: float = 2400.0
@export var fast_fall_gravity: float = 4800.0

# Dimensiones en píxeles configurables en Inspector
@export var stand_width: float = 54.0
@export var stand_height: float = 115.0
@export var duck_width: float = 76.0
@export var duck_height: float = 52.0

var velocity_y: float = 0.0
var ammo: int = 3
var is_dead: bool = false
var _jump_buffer: float = 0.0

@onready var visual: Node2D = $Visual
@onready var sprite: Sprite2D = $Visual/Sprite2D
@onready var stand_collision: CollisionShape2D = $StandCollision
@onready var duck_collision: CollisionShape2D = $DuckCollision

func _ready() -> void:
	add_to_group("runner_player")
	area_entered.connect(_on_area_entered)
	position.y = GROUND_Y
	_update_shapes()
	_set_standing_state()

func _update_shapes() -> void:
	var stand_shape = RectangleShape2D.new()
	stand_shape.size = Vector2(stand_width, stand_height)
	stand_collision.shape = stand_shape
	stand_collision.position = Vector2(0, -stand_height * 0.5)

	var duck_shape = RectangleShape2D.new()
	duck_shape.size = Vector2(duck_width, duck_height)
	duck_collision.shape = duck_shape
	duck_collision.position = Vector2(0, -duck_height * 0.5)

func _input(event: InputEvent) -> void:
	if is_dead:
		return

	# Salto (Espacio, Flechas, WASD y Gamepad ya están mapeados en jump)
	if event.is_action_pressed("jump"):
		try_jump()
	elif event.is_action_pressed("attack"):
		_shoot()

func try_jump() -> void:
	if is_dead:
		return
	if _is_duck_pressed():
		return

	# Si está en el suelo (con tolerancia de 10px) -> Salta inmediatamente
	if position.y >= GROUND_Y - 10.0:
		velocity_y = jump_velocity
		position.y -= 4.0 # Despegar del suelo para iniciar ascenso
		state = State.JUMPING
		_jump_buffer = 0.0
		AudioManager.play_sfx(&"sfx_run_jump")
		_set_standing_state()
	else:
		# En el aire -> Guardar en buffer para saltar tan pronto aterrice
		_jump_buffer = 0.18

func _is_duck_pressed() -> bool:
	return Input.is_action_pressed("crouch")

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	var is_on_ground: bool = position.y >= GROUND_Y
	var wants_duck: bool = _is_duck_pressed()

	# Control de buffer de salto
	if _jump_buffer > 0.0:
		_jump_buffer -= delta
		if is_on_ground and not wants_duck:
			try_jump()
			return

	# Control de estados en suelo
	if is_on_ground and state != State.JUMPING:
		velocity_y = 0.0
		position.y = GROUND_Y
		if wants_duck:
			if state != State.DUCKING:
				AudioManager.play_sfx(&"sfx_run_duck")
				_set_ducking_state()
		else:
			if state == State.DUCKING:
				AudioManager.play_sfx(&"sfx_run_stand")
				_set_standing_state()

	# Físicas en el aire o durante el salto
	if not is_on_ground or state == State.JUMPING:
		var current_gravity = fast_fall_gravity if wants_duck else jump_gravity
		velocity_y += current_gravity * delta
		position.y += velocity_y * delta

		# Aterrizaje
		if position.y >= GROUND_Y:
			position.y = GROUND_Y
			velocity_y = 0.0
			state = State.RUNNING
			AudioManager.play_sfx(&"sfx_run_land")
			if _jump_buffer > 0.0 and not wants_duck:
				try_jump()
			elif wants_duck:
				_set_ducking_state()
			else:
				_set_standing_state()

func _set_standing_state() -> void:
	if position.y < GROUND_Y:
		state = State.JUMPING
	else:
		state = State.RUNNING
	stand_collision.disabled = false
	duck_collision.disabled = true
	
	visual.position = Vector2(0, -stand_height * 0.5)
	var tex = sprite.texture
	var base_w: float = float(tex.get_width()) if tex != null else 138.0
	var base_h: float = float(tex.get_height()) if tex != null else 271.0
	sprite.scale = Vector2(stand_width / base_w, stand_height / base_h)
	sprite.modulate = Color.WHITE

func _set_ducking_state() -> void:
	state = State.DUCKING
	stand_collision.disabled = true
	duck_collision.disabled = false
	
	visual.position = Vector2(0, -duck_height * 0.5)
	var tex = sprite.texture
	var base_w: float = float(tex.get_width()) if tex != null else 138.0
	var base_h: float = float(tex.get_height()) if tex != null else 271.0
	sprite.scale = Vector2(duck_width / base_w, duck_height / base_h)
	sprite.modulate = Color(0.9, 0.9, 0.9)

func _shoot() -> void:
	if ammo > 0:
		ammo -= 1
		AudioManager.play_sfx(&"sfx_run_shoot")
		var bullet: MG_RunnerBullet = BULLET_SCENE.instantiate() as MG_RunnerBullet
		bullet.player = self
		get_parent().add_child(bullet)
		var spawn_y = position.y - (duck_height * 0.5 if state == State.DUCKING else stand_height * 0.5)
		bullet.global_position = Vector2(global_position.x + (duck_width * 0.6 if state == State.DUCKING else stand_width * 0.6), spawn_y)
	else:
		AudioManager.play_sfx(&"sfx_run_shoot_empty")

func add_ammo(amount: int) -> void:
	ammo = mini(3, ammo + amount)

func _on_area_entered(area: Area2D) -> void:
	if is_dead:
		return

	if area.is_in_group("runner_obstacle") or area.is_in_group("runner_enemy"):
		_die()

func _die() -> void:
	is_dead = true
	AudioManager.play_ui(&"sfx_run_death")
	sprite.modulate = Color(1.0, 0.2, 0.2)
	died.emit()
