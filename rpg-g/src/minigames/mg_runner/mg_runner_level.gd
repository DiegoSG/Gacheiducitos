extends Node2D

const OBSTACLE_SCENE = preload("res://src/minigames/mg_runner/mg_runner_obstacle.tscn")
const COIN_SCENE = preload("res://src/minigames/mg_runner/mg_runner_coin.tscn")
const ENEMY_SCENE = preload("res://src/minigames/mg_runner/mg_runner_enemy.tscn")

var config = {}

# Parámetros del nivel
var mode: int = 0
var target_value: float = 1500.0
var coin_density: float = 0.4

var current_distance: float = 0.0
var run_speed: float = 300.0
var is_playing: bool = false

# Control de generación
var spawn_timer: float = 0.0
var time_between_spawns: float = 1.0
var lines_passed: int = 0
var coins_collected: int = 0

const LANE_POSITIONS = [-160, 0, 160]
var spawn_y: float = -1000.0

enum CoinPattern { LINEA, DIAGONAL, V, V_INVERTIDA, CRUZ }

@onready var player = $RunnerPlayer
@onready var distance_label = $UI/DistanceLabel
@onready var result_label = $UI/ResultLabel

var ammo_label: Label

func _ready():
	config = GameManager.minigame_config
	mode = config.get("win_condition", 0) # 0: Distancia, 1: Obstáculos, 2: Monedas
	target_value = config.get("target_value", 1500.0)
	run_speed = config.get("run_speed", 300.0)
	coin_density = config.get("coin_density", 0.4)
	
	# Cálculo de frecuencia basado en la velocidad
	time_between_spawns = 1.2 * (300.0 / run_speed)
	
	# Añadir label de balas por código
	ammo_label = Label.new()
	ammo_label.position = Vector2(10, 40)
	ammo_label.add_theme_font_size_override("font_size", 24)
	$UI.add_child(ammo_label)
	
	player.died.connect(_on_player_died)
	_start_game()

func _start_game():
	is_playing = true
	current_distance = 0.0
	lines_passed = 0
	coins_collected = 0
	result_label.hide()

func _process(delta: float):
	if not is_playing:
		return
		
	# Reducir el incremento de distancia
	var distance_factor = config.get("distance_factor", 0.1)
	current_distance += (run_speed * distance_factor) * delta
	
	# Update UI & Check Win
	if mode == 0:
		distance_label.text = "Distancia: %d / %d m" % [int(current_distance), int(target_value)]
		if current_distance >= target_value:
			_win_game()
	elif mode == 1:
		distance_label.text = "Líneas pasadas: %d / %d" % [lines_passed, int(target_value)]
		if lines_passed >= target_value:
			_win_game()
	elif mode == 2:
		distance_label.text = "Monedas: %d / %d" % [coins_collected, int(target_value)]
		if coins_collected >= target_value:
			_win_game()
			
	if player:
		ammo_label.text = "Balas: %d/3" % player.ammo
		
	# Spawning Logic
	spawn_timer -= delta
	if spawn_timer <= 0:
		_spawn_obstacles()
		spawn_timer = time_between_spawns

func _spawn_obstacles():
	var available_lanes = [0, 1, 2]
	available_lanes.shuffle()
	
	var num_obs = randi_range(1, 3)
	
	# 20% de probabilidad de que la ola sea de enemigos en vez de cajas
	var is_enemy_wave = randf() < 0.2
	
	for i in range(num_obs):
		var lane_idx = available_lanes[i]
		
		if is_enemy_wave:
			var enemy = ENEMY_SCENE.instantiate()
			enemy.speed = run_speed
			enemy.position = Vector2(LANE_POSITIONS[lane_idx], spawn_y)
			add_child(enemy)
		else:
			var obs_type = randi_range(1, 2)
			if num_obs == 3 and i == 2:
				obs_type = 1 # Siempre uno saltable si los 3 carriles están ocupados (o 3 enemigos donde uno se muere)
			
			var obs = OBSTACLE_SCENE.instantiate()
			obs.obstacle_type = obs_type
			obs.speed = run_speed
			obs.position = Vector2(LANE_POSITIONS[lane_idx], spawn_y)
			add_child(obs)
		
	lines_passed += 1
	
	if randf() < coin_density:
		_spawn_coin_pattern(spawn_y - 200.0)

func _spawn_coin_pattern(y_base: float):
	var pattern = randi() % 5
	var lanes = [0, 1, 2]
	var y_spacing = 80.0
	
	match pattern:
		CoinPattern.LINEA:
			var l = lanes[randi() % 3]
			for i in range(5):
				_spawn_one_coin(l, y_base - (i * y_spacing))
		CoinPattern.DIAGONAL:
			var start_left = randf() > 0.5
			var steps = [0, 1, 2] if start_left else [2, 1, 0]
			for i in range(3):
				_spawn_one_coin(steps[i], y_base - (i * y_spacing))
		CoinPattern.V:
			_spawn_one_coin(0, y_base)
			_spawn_one_coin(2, y_base)
			_spawn_one_coin(1, y_base - y_spacing)
		CoinPattern.V_INVERTIDA:
			_spawn_one_coin(1, y_base)
			_spawn_one_coin(0, y_base - y_spacing)
			_spawn_one_coin(2, y_base - y_spacing)
		CoinPattern.CRUZ:
			_spawn_one_coin(1, y_base)
			_spawn_one_coin(0, y_base - y_spacing)
			_spawn_one_coin(1, y_base - y_spacing)
			_spawn_one_coin(2, y_base - y_spacing)
			_spawn_one_coin(1, y_base - (y_spacing * 2))

func _spawn_one_coin(lane_idx: int, y_pos: float):
	var coin = COIN_SCENE.instantiate()
	coin.speed = run_speed
	coin.position = Vector2(LANE_POSITIONS[lane_idx], y_pos)
	coin.collected.connect(_on_coin_collected)
	add_child(coin)

func _on_coin_collected():
	coins_collected += 1
	PlayerStats.add_gold(1)

func _stop_all_objects():
	for c in get_children():
		if "speed" in c:
			c.speed = 0

func _on_player_died():
	is_playing = false
	_stop_all_objects()
	result_label.text = "¡Chocaste!\nPresiona ESC para salir"
	result_label.modulate = Color(1, 0, 0)
	result_label.show()

func _win_game():
	is_playing = false
	_stop_all_objects()
	result_label.text = "¡Superado!\nVolviendo al mapa..."
	result_label.modulate = Color(0, 1, 0)
	result_label.show()
	
	# Esperar 2 segundos y salir
	await get_tree().create_timer(2.0).timeout
	GameManager.return_to_overworld()

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		GameManager.return_to_overworld()
