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
@export var item_pool: Array[String] = ["blue_potion", "red_potion", "green_herb"]

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
	var cfg = GameManager.minigame_config
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
	
	if cfg.has("item_pool") and cfg["item_pool"] is Array:
		var arr: Array[String] = []
		for it in cfg["item_pool"]:
			arr.append(str(it))
		item_pool = arr

func _start_game() -> void:
	is_playing = true
	current_distance = 0.0
	coins_collected = 0
	total_coins_spawned = 0
	target_object_spawned = false
	time_between_spawns = 1.7 * (350.0 / run_speed)
	spawn_timer = 1.0 # Breve respiro al iniciar

func _process(delta: float) -> void:
	if not is_playing:
		return
		
	# Distancia
	current_distance += (run_speed * distance_factor) * delta
	
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
		spawn_timer = time_between_spawns + randf_range(-0.2, 0.3)

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

func _spawn_wave() -> void:
	var roll = randf()
	
	if roll < 0.40:
		# Ola de Obstáculo Terrestre (Salto) + monedas en arco opcional
		_spawn_obstacle(MG_RunnerObstacle.ObstacleType.LOW)
		if randf() < coin_density and _can_spawn_more_coins():
			_spawn_coin_pattern(CoinPattern.V_INVERTED, SPAWN_X)
	elif roll < 0.70:
		# Ola de Obstáculo Aéreo (Agacharse)
		_spawn_obstacle(MG_RunnerObstacle.ObstacleType.HIGH)
		if randf() < coin_density and _can_spawn_more_coins():
			# Monedas a ras de suelo para premiar agacharse
			_spawn_coin_pattern(CoinPattern.LINE_2, SPAWN_X + 80.0)
	elif roll < 0.82:
		# Ola de Enemigo frontal
		_spawn_enemy()
	else:
		# Tramo libre con patrón de monedas o ítem
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
			positions.append(Vector2(spacing_x * 2, GROUND_Y - 35.0)) # Altura agachado
			positions.append(Vector2(spacing_x * 3, GROUND_Y - 95.0))
			positions.append(Vector2(spacing_x * 4, GROUND_Y - 140.0))
		CoinPattern.V_INVERTED:
			# Patrón en V Invertida (Arco parabólico de salto sobre obstáculo de suelo)
			positions.append(Vector2(0, GROUND_Y - 50.0))
			positions.append(Vector2(spacing_x, GROUND_Y - 110.0))
			positions.append(Vector2(spacing_x * 2, GROUND_Y - 175.0)) # Cima del salto
			positions.append(Vector2(spacing_x * 3, GROUND_Y - 110.0))
			positions.append(Vector2(spacing_x * 4, GROUND_Y - 50.0))
			
	for pos in positions:
		if not _can_spawn_more_coins():
			break
		var pickup = PICKUP_SCENE.instantiate() as MG_RunnerPickup
		pickup.pickup_type = MG_RunnerPickup.PickupType.COIN
		pickup.item_id = "gold_coins"
		pickup.amount = 1
		pickup.speed = run_speed
		pickup.position = Vector2(base_x + pos.x, pos.y)
		pickup.collected.connect(_on_coin_collected)
		world_objects.add_child(pickup)
		total_coins_spawned += 1

func _spawn_random_item() -> void:
	if item_pool.is_empty():
		return
	var rand_id = item_pool[randi() % item_pool.size()]
	var pickup = PICKUP_SCENE.instantiate() as MG_RunnerPickup
	pickup.pickup_type = MG_RunnerPickup.PickupType.RANDOM_ITEM
	pickup.item_id = rand_id
	pickup.amount = 1
	pickup.speed = run_speed
	# Spawn a ras de suelo o a media altura
	var spawn_height = GROUND_Y - (40.0 if randf() > 0.5 else 110.0)
	pickup.position = Vector2(SPAWN_X, spawn_height)
	pickup.collected.connect(_on_random_item_collected)
	world_objects.add_child(pickup)

func _on_coin_collected(_p: MG_RunnerPickup) -> void:
	coins_collected += 1
	add_reward("gold_coins", 1)

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

func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if is_playing and event.is_action_pressed("ui_cancel"):
		finish(false)
