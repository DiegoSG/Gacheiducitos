extends Node2D

const OBSTACLE_SCENE = preload("res://scenes/minigames/mg_runner/mg_runner_obstacle.tscn")

var config = {}

# Parámetros del nivel
var target_distance: float = 1000.0
var total_obstacles: int = 20

var current_distance: float = 0.0
var run_speed: float = 300.0
var is_playing: bool = false

# Control de generación
var spawn_timer: float = 0.0
var time_between_spawns: float = 1.0
var obstacles_spawned: int = 0

const LANE_POSITIONS = [-160, 0, 160]
var spawn_y: float = -1000.0

@onready var player = $RunnerPlayer
@onready var distance_label = $UI/DistanceLabel
@onready var result_label = $UI/ResultLabel

func _ready():
	config = GameManager.minigame_config
	target_distance = config.get("distance", 1500.0)
	total_obstacles = config.get("obstacles", 25)
	
	# Cálculo de frecuencia
	var total_time = target_distance / run_speed
	time_between_spawns = total_time / float(total_obstacles)
	
	player.died.connect(_on_player_died)
	_start_game()

func _start_game():
	is_playing = true
	current_distance = 0.0
	obstacles_spawned = 0
	result_label.hide()

func _process(delta: float):
	if not is_playing:
		return
		
	current_distance += run_speed * delta
	distance_label.text = "Distancia: %d / %d m" % [int(current_distance), int(target_distance)]
	
	if current_distance >= target_distance:
		_win_game()
		return
		
	spawn_timer -= delta
	if spawn_timer <= 0 and obstacles_spawned < total_obstacles:
		_spawn_obstacles()
		spawn_timer = time_between_spawns

func _spawn_obstacles():
	# Algoritmo de generación que asegura que siempre se pueda pasar.
	# "No podemos tener 3 obstáculos de 3 de altura en las 3 líneas al mismo tiempo"
	# Tipos: 1 = Bajo(salta), 2 = Alto(agacha), 3 = Muro(esquiva)
	
	var lanes_to_spawn = []
	# Elegir cuántos obstáculos en esta "ola": 1 o 2. Rara vez 3 (solo si al menos 1 es de tipo 1 o 2).
	var num_obs = randi_range(1, 3)
	
	var available_lanes = [0, 1, 2]
	available_lanes.shuffle()
	
	var types_in_wave = []
	
	for i in range(num_obs):
		var lane_idx = available_lanes[i]
		var obs_type = randi_range(1, 3)
		
		# Si vamos a poner 3 obstáculos en la misma ola, forzar que al menos el último no sea Muro (3)
		if num_obs == 3 and i == 2:
			var has_passable = false
			for t in types_in_wave:
				if t != 3:
					has_passable = true
			if not has_passable:
				obs_type = randi_range(1, 2) # Forzar pasable
				
		types_in_wave.append(obs_type)
		
		var obs = OBSTACLE_SCENE.instantiate()
		obs.obstacle_type = obs_type
		obs.speed = run_speed
		obs.position = Vector2(LANE_POSITIONS[lane_idx], spawn_y)
		add_child(obs)
		
	obstacles_spawned += num_obs

func _on_player_died():
	is_playing = false
	result_label.text = "¡Chocaste!\nPresiona ESC para salir"
	result_label.modulate = Color(1, 0, 0)
	result_label.show()

func _win_game():
	is_playing = false
	result_label.text = "¡Superado!\nVolviendo al mapa..."
	result_label.modulate = Color(0, 1, 0)
	result_label.show()
	
	# Esperar 2 segundos y salir
	await get_tree().create_timer(2.0).timeout
	GameManager.return_to_overworld()

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		GameManager.return_to_overworld()
