extends CharacterBody2D
class_name MG_TrampolinPlayer

signal died

const GRAVITY = 800.0
const JUMP_FORCE = -600.0
const MOVE_SPEED = 400.0

var screen_width = 1920.0 # Se ajustará en _ready si es necesario
var game_area_width = 600.0 # El ancho central donde ocurre el juego

func _physics_process(delta: float):
	# Aplicar gravedad
	velocity.y += GRAVITY * delta
	
	# Movimiento horizontal
	var direction = Input.get_axis("ui_left", "ui_right")
	velocity.x = direction * MOVE_SPEED
	
	# Mover y detectar colisiones
	var collision = move_and_collide(velocity * delta)
	
	if collision:
		var collider = collision.get_collider()
		# Solo rebotar si estamos cayendo y chocamos con la parte superior de algo
		if velocity.y > 0 and collider.is_in_group("trampolin_platform"):
			velocity.y = JUMP_FORCE
			# Emitir un sonido o efecto aquí si se desea
	
	# Wrap horizontal (Teletransporte al otro lado)
	var half_width = game_area_width / 2.0
	if global_position.x > half_width:
		global_position.x = -half_width
	elif global_position.x < -half_width:
		global_position.x = half_width

func die():
	died.emit()
	queue_free()
