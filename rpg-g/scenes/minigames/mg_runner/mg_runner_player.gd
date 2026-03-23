extends Area2D
class_name MG_RunnerPlayer

signal died

enum State { NORMAL, JUMPING, DUCKING }
var state: State = State.NORMAL

var lane: int = 1 # 0 = Left, 1 = Center, 2 = Right
const LANE_POSITIONS = [-160, 0, 160] # X offsets relative to center

var action_timer: float = 0.0
const JUMP_DURATION = 0.6
const DUCK_DURATION = 0.6

@onready var visual = $Visual
@onready var sprite = $Visual/Sprite2D

func _ready():
	position.x = LANE_POSITIONS[lane]
	area_entered.connect(_on_area_entered)

func _process(delta: float):
	if state != State.NORMAL:
		action_timer -= delta
		
		if state == State.JUMPING:
			# Arco simple con seno
			var progress = 1.0 - (action_timer / JUMP_DURATION)
			visual.position.y = -sin(progress * PI) * 50.0
		elif state == State.DUCKING:
			sprite.scale.y = 0.5
			visual.position.y = 16.0 # Bajar un poco para compensar
			
		if action_timer <= 0.0:
			_reset_state()

func _reset_state():
	state = State.NORMAL
	visual.position.y = 0
	sprite.scale.y = 1.0

func _input(event):
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
		elif event.is_action_pressed("ui_down"): # Agacharse
			state = State.DUCKING
			action_timer = DUCK_DURATION

func _animate_lane_change():
	var tween = create_tween()
	tween.tween_property(self, "position:x", LANE_POSITIONS[lane], 0.15)

func _on_area_entered(area):
	if area.is_in_group("runner_obstacle"):
		var obs_type = area.obstacle_type
		# 1 = Bajo (Salta), 2 = Alto (Agáchate), 3 = Muro
		if obs_type == 1 and state != State.JUMPING:
			_die()
		elif obs_type == 2 and state != State.DUCKING:
			_die()
		elif obs_type == 3:
			_die()

func _die():
	died.emit()
	queue_free()
