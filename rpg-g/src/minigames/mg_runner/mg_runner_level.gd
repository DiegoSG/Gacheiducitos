extends MinigameBase

const OBSTACLE_SCENE = preload("res://src/minigames/mg_runner/mg_runner_obstacle.tscn")
const PICKUP_SCENE = preload("res://src/minigames/mg_runner/mg_runner_pickup.tscn")
const ENEMY_SCENE = preload("res://src/minigames/mg_runner/mg_runner_enemy.tscn")

enum WinCondition { DISTANCE = 0, OBJECT = 1 }
enum CoinPattern { LINE_1, LINE_2, LINE_3, LINE_4, V_SHAPE, V_INVERTED }

# Parámetros configurables
@export var win_condition: WinCondition = WinCondition.DISTANCE
@export var target_value: float = 1500.0
@export var target_item_id: String = "ancient_map"
@export var target_distance_range: Vector2 = Vector2(600.0, 1000.0)

@export var run_speed: float = 380.0
@export var distance_factor: float = 0.1
@export var coin_density: float = 0.55
@export var max_coins: int = -1 # -1 = Sin límite estricto
@export var item_spawn_rate: float = 0.25
@export var item_pool: Array = ["blue_potion", "red_potion", "green_herb"] # Puede ser Array[String] o Array[Dictionary]

# Aumento dinámico de velocidad
@export var speed_increase_interval: float = 200.0 # Cada cuántos metros acelera
@export var speed_increase_amount: float = 25.0 # Cuánta velocidad suma
var next_speed_increase_dist: float = 200.0

# Spawn de munición creciente
@export var ammo_spawn_initial_distance: float = 120.0
@export var ammo_spawn_distance_multiplier: float = 1.35
var next_ammo_spawn_distance: float = 120.0
var ammo_spawn_step: float = 120.0

# Anti-solapamiento: Registro del último X donde se generó un obstáculo/entidad
var last_spawned_x: float = 0.0
const MIN_OBSTACLE_SPACING: float = 320.0

const GROUND_Y: float = 820.0
const SPAWN_X: float = 2050.0

var current_distance: float = 0.0
var is_playing: bool = false
var coins_collected: int = 0
var total_coins_spawned: int = 0

# Control de spawns
var spawn_timer: float = 0.0
var time_between_spawns: float = 1.6
var target_spawn_distance: float = 0.0
var target_object_spawned: bool = false

# Scrolling de suelo
var ground_scroll_offset: float = 0.0

@onready var player: MG_RunnerPlayer = $RunnerPlayer
@onready var world_objects: Node2D = $WorldObjects
@onready var distance_label: Label = $UI/HUD/DistanceLabel
@onready var objective_label: Label = $UI/HUD/ObjectiveLabel
@onready var coins_label: Label = $UI/HUD/CoinsLabel
@onready var ammo_label: Label = $UI/HUD/AmmoLabel
@onready var ground_line: Line2D = $Environment/GroundTrack/GroundLine
@onready var ground_dashes: Node2D = $Environment/GroundTrack/Dashes

func _ready() -> void:
	_load_configuration()
	
	player.position = Vector2(280, GROUND_Y)
	player.died.connect(_on_player_died)
	
	if win_condition == WinCondition.OBJECT:
		target_spawn_distance = randf_range(target_distance_range.x, target_distance_range.y)
		objective_label.text = "Objetivo: Encontrar %s (~%d m)" % [target_item_id.capitalize().replace("_", " "), int(target_spawn_distance)]
	else:
		objective_label.text = "Objetivo: Recorrer %d m" % int(target_value)
		
	_start_game()

func _load_configuration() -> void:
	var cfg: Dictionary = GameManager.minigame_config
	if cfg.is_empty():
		return
		
	win_condition = cfg.get("win_condition", win_condition)
	target_value = cfg.get("target_value", target_value)
	target_item_id = cfg.get("target_item_id", target_item_id)
	
	if cfg.has("target_distance_range"):
		var r = cfg.get("target_distance_range")
		if r is Vector2:
			target_distance_range = r
		elif r is Array and r.size() >= 2:
			target_distance_range = Vector2(r[0], r[1])
			
	run_speed = cfg.get("run_speed", run_speed)
	distance_factor = cfg.get("distance_factor", distance_factor)
	coin_density = cfg.get("coin_density", coin_density)
	max_coins = cfg.get("max_coins", max_coins)
	item_spawn_rate = cfg.get("item_spawn_rate", item_spawn_rate)
	speed_increase_interval = cfg.get("speed_increase_interval", speed_increase_interval)
	speed_increase_amount = cfg.get("speed_increase_amount", speed_increase_amount)
	ammo_spawn_initial_distance = cfg.get("ammo_spawn_initial_distance", ammo_spawn_initial_distance)
	ammo_spawn_distance_multiplier = cfg.get("ammo_spawn_distance_multiplier", ammo_spawn_distance_multiplier)
	
	if cfg.has("item_pool") and cfg["item_pool"] is Array:
		item_pool = cfg["item_pool"]

func _start_game() -> void:
	is_playing = true
	current_distance = 0.0
	coins_collected = 0
	total_coins_spawned = 0
	target_object_spawned = false
	next_speed_increase_dist = speed_increase_interval
	next_ammo_spawn_distance = ammo_spawn_initial_distance
	ammo_spawn_step = ammo_spawn_initial_distance
	time_between_spawns = 1.7 * (350.0 / run_speed)
	spawn_timer = 1.0

func _process(delta: float) -> void:
	if not is_playing:
		return
		
	# Distancia
	current_distance += (run_speed * distance_factor) * delta
	
	# Comprobar aceleración de velocidad cada X distancia
	if current_distance >= next_speed_increase_dist:
		run_speed += speed_increase_amount
		next_speed_increase_dist += speed_increase_interval
		time_between_spawns = 1.7 * (350.0 / run_speed)
		# Actualizar velocidad de los objetos ya existentes en pantalla
		for c in world_objects.get_children():
			if "speed" in c and not (c is MG_RunnerEnemy):
				c.speed = run_speed
			elif c is MG_RunnerEnemy:
				c.speed = run_speed + 40.0
	
	# Comprobar aparición de munición a distancia creciente
	if current_distance >= next_ammo_spawn_distance:
		_spawn_ammo_pickup()
		ammo_spawn_step *= ammo_spawn_distance_multiplier
		next_ammo_spawn_distance += ammo_spawn_step

	# Scroll visual del suelo
	ground_scroll_offset = fmod(ground_scroll_offset + (run_speed * delta), 120.0)
	ground_dashes.position.x = -ground_scroll_offset
	
	_update_ui()
	_check_win_by_distance()
	_check_spawn_target_object()
	
	# Temporizador de olas de obstáculos y pickups
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_wave()
		spawn_timer = time_between_spawns + randf_range(-0.1, 0.2)

func _update_ui() -> void:
	if win_condition == WinCondition.DISTANCE:
		distance_label.text = "Distancia: %d / %d m" % [int(current_distance), int(target_value)]
	else:
		distance_label.text = "Distancia: %d m" % int(current_distance)

	coins_label.text = "Monedas: %d" % coins_collected
	ammo_label.text = "Balas (Z): %d/3" % player.ammo

func _check_win_by_distance() -> void:
	if win_condition == WinCondition.DISTANCE and current_distance >= target_value:
		_win_game()

func _check_spawn_target_object() -> void:
	if win_condition == WinCondition.OBJECT and not target_object_spawned:
		if current_distance >= target_spawn_distance:
			target_object_spawned = true
			_spawn_target_pickup()

func _spawn_target_pickup() -> void:
	var pickup = PICKUP_SCENE.instantiate() as MG_RunnerPickup
	pickup.is_victory_target = true
	pickup.item_id = target_item_id
	pickup.speed = run_speed
	# Colocar a ras de suelo para que sea recogida fácilmente
	pickup.position = Vector2(SPAWN_X, GROUND_Y - 45.0)
	pickup.collected.connect(_on_target_pickup_collected)
	world_objects.add_child(pickup)

func _on_target_pickup_collected(p: MG_RunnerPickup) -> void:
	add_reward(p.item_id, 1)
	_win_game()

func _spawn_ammo_pickup() -> void:
	var pickup = PICKUP_SCENE.instantiate() as MG_RunnerPickup
	pickup.pickup_type = MG_RunnerPickup.PickupType.AMMO
	pickup.speed = run_speed
	# Se coloca flotando a altura media/baja
	pickup.position = Vector2(SPAWN_X + 150.0, GROUND_Y - 55.0)
	pickup.collected.connect(func(_p) -> void:
		player.add_ammo(1)
	)
	world_objects.add_child(pickup)

func _spawn_wave() -> void:
	var roll: float = randf()
	
	if roll < 0.38:
		# Ola de Obstáculo Terrestre (Salto) + monedas en arco seguro
		_spawn_obstacle(MG_RunnerObstacle.ObstacleType.LOW)
		if randf() < coin_density and _can_spawn_more_coins():
			# El arco V_INVERTED acompaña el salto del obstáculo
			_spawn_coin_pattern(CoinPattern.V_INVERTED, SPAWN_X)
	elif roll < 0.68:
		# Ola de Obstáculo Aéreo (Agacharse)
		_spawn_obstacle(MG_RunnerObstacle.ObstacleType.HIGH)
		if randf() < coin_density and _can_spawn_more_coins():
			# Monedas a ras de suelo colocadas con offset seguro bajo el obstáculo
			_spawn_coin_pattern(CoinPattern.LINE_2, SPAWN_X + 60.0)
	elif roll < 0.82:
		# Ola de Enemigo frontal
		_spawn_enemy()
	else:
		# Tramo libre de obstáculos: sólo monedas o items con distancia limpia
		if randf() < item_spawn_rate and not item_pool.is_empty():
			_spawn_random_item()
		elif _can_spawn_more_coins():
			var pattern = randi() % 6
			_spawn_coin_pattern(pattern as CoinPattern, SPAWN_X)

func _spawn_obstacle(type: MG_RunnerObstacle.ObstacleType) -> void:
	var obs = OBSTACLE_SCENE.instantiate() as MG_RunnerObstacle
	obs.obstacle_type = type
	obs.speed = run_speed
	obs.position = Vector2(SPAWN_X, GROUND_Y)
	world_objects.add_child(obs)

func _spawn_enemy() -> void:
	var enemy = ENEMY_SCENE.instantiate() as MG_RunnerEnemy
	enemy.speed = run_speed + 40.0
	enemy.position = Vector2(SPAWN_X, GROUND_Y - 30.0)
	world_objects.add_child(enemy)

func _can_spawn_more_coins() -> bool:
	if max_coins <= 0:
		return true
	return total_coins_spawned < max_coins

func _spawn_coin_pattern(pattern: CoinPattern, base_x: float) -> void:
	var positions: Array[Vector2] = []
	var spacing_x: float = 70.0
	
	match pattern:
		CoinPattern.LINE_1:
			positions.append(Vector2(0, GROUND_Y - 55.0))
		CoinPattern.LINE_2:
			positions.append(Vector2(0, GROUND_Y - 55.0))
			positions.append(Vector2(spacing_x, GROUND_Y - 55.0))
		CoinPattern.LINE_3:
			for i in range(3):
				positions.append(Vector2(i * spacing_x, GROUND_Y - 55.0))
		CoinPattern.LINE_4:
			for i in range(4):
				positions.append(Vector2(i * spacing_x, GROUND_Y - 55.0))
		CoinPattern.V_SHAPE:
			# Patrón en V (baja al centro y sube)
			positions.append(Vector2(0, GROUND_Y - 140.0))
			positions.append(Vector2(spacing_x, GROUND_Y - 95.0))
			positions.append(Vector2(spacing_x * 2, GROUND_Y - 35.0))
			positions.append(Vector2(spacing_x * 3, GROUND_Y - 95.0))
			positions.append(Vector2(spacing_x * 4, GROUND_Y - 140.0))
		CoinPattern.V_INVERTED:
			# Patrón en V Invertida (Arco parabólico limpio sobre obstáculo de suelo)
			positions.append(Vector2(-spacing_x * 2, GROUND_Y - 50.0))
			positions.append(Vector2(-spacing_x, GROUND_Y - 110.0))
			positions.append(Vector2(0, GROUND_Y - 180.0)) # Cima sobre el obstáculo
			positions.append(Vector2(spacing_x, GROUND_Y - 110.0))
			positions.append(Vector2(spacing_x * 2, GROUND_Y - 50.0))
			
	for pos in positions:
		if not _can_spawn_more_coins():
			break
		var pickup = PICKUP_SCENE.instantiate() as MG_RunnerPickup
		pickup.pickup_type = MG_RunnerPickup.PickupType.COIN
		pickup.item_id = Inventory.GOLD_ITEM_ID
		pickup.amount = 1
		pickup.speed = run_speed
		pickup.position = Vector2(base_x + pos.x, pos.y)
		pickup.collected.connect(_on_coin_collected)
		world_objects.add_child(pickup)
		total_coins_spawned += 1

func _spawn_random_item() -> void:
	if item_pool.is_empty():
		return
	var chosen_id: String = pick_item_from_pool(item_pool)
	if chosen_id.is_empty():
		return

	var pickup: MG_RunnerPickup = PICKUP_SCENE.instantiate() as MG_RunnerPickup
	pickup.pickup_type = MG_RunnerPickup.PickupType.RANDOM_ITEM
	pickup.item_id = chosen_id
	pickup.amount = 1
	pickup.speed = run_speed
	var spawn_height = GROUND_Y - (45.0 if randf() > 0.5 else 115.0)
	pickup.position = Vector2(SPAWN_X, spawn_height)
	pickup.collected.connect(_on_random_item_collected)
	world_objects.add_child(pickup)

func _on_coin_collected(_p: MG_RunnerPickup) -> void:
	coins_collected += 1
	add_reward(Inventory.GOLD_ITEM_ID, 1)

func _on_random_item_collected(p: MG_RunnerPickup) -> void:
	add_reward(p.item_id, p.amount)

func _stop_world() -> void:
	for c in world_objects.get_children():
		if "speed" in c:
			c.speed = 0.0

func _on_player_died() -> void:
	is_playing = false
	_stop_world()
	finish(false)

func _win_game() -> void:
	is_playing = false
	_stop_world()
	finish(true)

