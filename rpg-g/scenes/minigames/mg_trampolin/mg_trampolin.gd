extends Node2D

@export var platform_scene: PackedScene = preload("res://scenes/minigames/mg_trampolin/mg_trampolin_platform.tscn")
@export var player_scene: PackedScene = preload("res://scenes/minigames/mg_trampolin/mg_trampolin_player.tscn")

@onready var camera = $Camera2D
@onready var platforms_container = $Platforms

var player: MG_TrampolinPlayer
var last_platform_y: float = 0.0
var spawn_distance: float = 120.0
var game_width: float = 600.0
var max_score: float = 0.0

func _ready():
	# Configuración inicial del juego
	last_platform_y = get_viewport_rect().size.y - 100.0
	
	# Spawn del jugador
	player = player_scene.instantiate()
	add_child(player)
	player.global_position = Vector2(0, last_platform_y - 50.0)
	player.died.connect(_on_player_died)
	
	# Centrar cámara en el jugador inicial
	camera.global_position.y = player.global_position.y
	
	# Crear base sólida al inicio
	spawn_base_floor()
	
	# Crear plataformas iniciales hacia arriba
	for i in range(12):
		spawn_platform()

func _process(_delta):
	if !player: return
	
	# La cámara sigue al jugador solo HACIA ARRIBA
	if player.global_position.y < camera.global_position.y:
		camera.global_position.y = player.global_position.y
	
	# Generar nuevas plataformas a medida que subimos
	if player.global_position.y < last_platform_y + 1200:
		spawn_platform()
		
	# Actualizar Score basado en la altura máxima alcanzada (Y negativa)
	var current_score = floor(-player.global_position.y / 10.0)
	if current_score > max_score:
		max_score = current_score
		$UI/ScoreLabel.text = "Score: " + str(max_score)
		
	# Limpieza de plataformas viejas (opcional, para performance)
	for plat in platforms_container.get_children():
		if plat.global_position.y > camera.global_position.y + 600:
			plat.queue_free()
			
	# Detectar Game Over (caída fuera de cámara)
	if player.global_position.y > camera.global_position.y + 600:
		_game_over()

func spawn_platform():
	var new_plat = platform_scene.instantiate()
	platforms_container.add_child(new_plat)
	
	# Posición aleatoria en el ancho del juego
	var x_pos = randf_range(-game_width/2.0 + 40, game_width/2.0 - 40)
	last_platform_y -= spawn_distance
	new_plat.global_position = Vector2(x_pos, last_platform_y)

func _on_player_died():
	_game_over()

func _game_over():
	# Volver al overworld tras un pequeño delay o inmediatamente
	# Aquí podrías añadir una UI de Score
	print("GAME OVER - Trampolin")
	# Detener proceso para evitar múltiples llamadas
	set_process(false)
	
	# Guardar Score (opcional)
	# PlayerStats.last_score = ...
	
	# Volver al overworld
	get_tree().create_timer(1.0).timeout.connect(func():
		GameManager.return_to_overworld()
	)

func spawn_base_floor():
	# Crear una fila de plataformas que cubran el suelo inicial
	var start_y = last_platform_y + 100.0
	for x in range(-300, 301, 80):
		var base_plat = platform_scene.instantiate()
		platforms_container.add_child(base_plat)
		base_plat.global_position = Vector2(x, start_y)
