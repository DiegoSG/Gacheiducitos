extends Area2D
class_name MG_RunnerPlayer

signal died

enum State { NORMAL, JUMPING }
var state: State = State.NORMAL

var lane: int = 1 # 0 = Left, 1 = Center, 2 = Right
const LANE_POSITIONS = [-160, 0, 160] # X offsets relative to center

var action_timer: float = 0.0
const JUMP_DURATION = 0.6

var ammo: int = 3
const BULLET_SCENE = preload("res://src/minigames/mg_runner/mg_runner_bullet.tscn")

var is_dead: bool = false

@onready var visual = $Visual
@onready var sprite = $Visual/Sprite2D

func _ready():
	add_to_group("runner_player")
	position.x = LANE_POSITIONS[lane]
	area_entered.connect(_on_area_entered)

func _process(delta: float):
	if is_dead:
		return
		
	if state != State.NORMAL:
		action_timer -= delta
		
		if state == State.JUMPING:
			# Limitar action_timer para que no baje de 0 antes del reseteo visual
			var current_timer = max(0.0, action_timer)
			var progress = 1.0 - (current_timer / JUMP_DURATION)
			visual.position.y = -sin(progress * PI) * 30.0
			var jump_scale = 1.0 + (sin(progress * PI) * 0.4)
			sprite.scale = Vector2(jump_scale, jump_scale)
			
		if action_timer <= 0.0:
			_reset_state()

func _reset_state():
	state = State.NORMAL
	visual.position.y = 0
	sprite.scale = Vector2(1.0, 1.0)
	
func _input(event):
	if is_dead:
		return
		
	if state == State.NORMAL:
		if event.is_action_pressed("ui_left"):
			if lane > 0:
				lane -= 1
				_animate_lane_change()
		elif event.is_action_pressed("ui_right"):
			if lane < 2:
				lane += 1
				_animate_lane_change()
		elif event.is_action_pressed("ui_accept"): # Salto
			state = State.JUMPING
			action_timer = JUMP_DURATION
		elif event is InputEventKey and event.keycode == KEY_Z and event.pressed and not event.echo:
			_shoot()

func _shoot():
	if ammo > 0:
		ammo -= 1
		var bullet = BULLET_SCENE.instantiate()
		bullet.player = self
		get_parent().add_child(bullet)
		bullet.global_position = global_position - Vector2(0, 30)

func add_ammo(amount: int):
	ammo += amount
	if ammo > 3:
		ammo = 3

func _animate_lane_change():
	var tween = create_tween()
	tween.tween_property(self, "position:x", LANE_POSITIONS[lane], 0.15)

func _on_area_entered(area):
	if is_dead:
		return
		
	if area.is_in_group("runner_obstacle"):
		var obs_type = 2
		if "obstacle_type" in area:
			obs_type = area.obstacle_type
			
		if obs_type == 1 and state != State.JUMPING:
			_die()
		elif obs_type == 2:
			_die()
	elif area.is_in_group("runner_enemy"):
		_die()

func _die():
	is_dead = true
	sprite.modulate = Color(1, 0, 0)
	died.emit()
