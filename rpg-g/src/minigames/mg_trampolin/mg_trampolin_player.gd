extends CharacterBody2D
class_name MG_TrampolinPlayer

signal died

const GRAVITY = 800.0
const JUMP_FORCE = -600.0
const MOVE_SPEED = 400.0

var game_area_width: float = 600.0 ## El ancho central donde ocurre el juego

@onready var sprite: Sprite2D = $Sprite2D

const TEX_DOWN = preload("res://assets/sprites/player_down.png")
const TEX_SIDE = preload("res://assets/sprites/player_side.png")
const TEX_UP = preload("res://assets/sprites/player_up.png")

func _physics_process(delta: float):
	# Aplicar gravedad
	velocity.y += GRAVITY * delta
	
	# Movimiento horizontal
	var direction = Input.get_axis("ui_left", "ui_right")
	velocity.x = direction * MOVE_SPEED
	
	if sprite:
		if direction > 0:
			sprite.texture = TEX_SIDE
			sprite.flip_h = false
		elif direction < 0:
			sprite.texture = TEX_SIDE
			sprite.flip_h = true
		elif velocity.y < 0:
			sprite.texture = TEX_UP
			sprite.flip_h = false
		else:
			sprite.texture = TEX_DOWN
			sprite.flip_h = false
	
	# Mover y detectar colisiones
	var collision = move_and_collide(velocity * delta)
	
	if collision:
		var collider = collision.get_collider()
		# Solo rebotar si estamos cayendo y chocamos con la parte superior de algo
		if velocity.y > 0 and collider.is_in_group("trampolin_platform"):
			velocity.y = JUMP_FORCE
			if collider.is_in_group("special_platform"):
				get_parent()._win_game("¡Trampolín especial encontrado!")
	
	# Paredes sólidas (bloqueo)
	var half_width = game_area_width / 2.0
	if global_position.x > half_width:
		global_position.x = half_width
		velocity.x = 0
	elif global_position.x < -half_width:
		global_position.x = -half_width
		velocity.x = 0

func die():
	died.emit()
	queue_free()
