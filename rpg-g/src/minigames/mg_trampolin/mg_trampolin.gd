extends MinigameBase

const PLATFORM_SCENE: PackedScene = preload("res://src/minigames/mg_trampolin/mg_trampolin_platform.tscn")
const PLAYER_SCENE: PackedScene = preload("res://src/minigames/mg_trampolin/mg_trampolin_player.tscn")
const COIN_SCENE: PackedScene = preload("res://src/minigames/mg_trampolin/mg_trampolin_coin.tscn")
const ITEM_SCENE: PackedScene = preload("res://src/minigames/mg_trampolin/mg_trampolin_item.tscn")

@onready var camera = $Camera2D
@onready var platforms_container = $Platforms

var player: MG_TrampolinPlayer
var last_platform_y: float = 0.0
var spawn_distance: float = 120.0
var game_width: float = 600.0
var max_score: float = 0.0
var _last_height_sound_score: float = 0.0

const HEIGHT_SOUND_SCORE_STEP: float = 50.0

@export var cleanup_threshold: float = 300.0

# Configuración y Estado
var config = {}
var coins_collected = 0
var win_condition_met = false
var special_platform_spawned = false
var item_pool: Array = [] # Array[Dictionary]: [{"id": "blue_potion", "chance": 0.25}, ...]

enum WinCondition { ALTURA, ESPECIAL, MONEDAS }
enum CoinPattern { LINEA, CUADRO, V, V_INVERTIDA }

func _ready() -> void:
	config = GameManager.minigame_config
	if config.has("item_pool") and config["item_pool"] is Array:
		item_pool = config["item_pool"]
	
	# Configuración inicial del juego
	last_platform_y = get_viewport_rect().size.y - 100.0
	
	# Spawn del jugador
	player = PLAYER_SCENE.instantiate() as MG_TrampolinPlayer
	add_child(player)
	player.global_position = Vector2(0, last_platform_y - 50.0)
	player.special_platform_reached.connect(_on_special_platform_reached)
	
	# Centrar cámara en el jugador inicial
	camera.make_current()
	camera.global_position.y = player.global_position.y
	
	# Crear base sólida al inicio
	spawn_base_floor()
	
	# Crear plataformas iniciales hacia arriba
	for i in range(12):
		spawn_platform()

func _process(_delta: float) -> void:
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
		if max_score - _last_height_sound_score >= HEIGHT_SOUND_SCORE_STEP:
			_last_height_sound_score = max_score
			AudioManager.play_sfx(&"sfx_tramp_height")
	
	# Verificar condiciones de victoria
	_check_win_conditions()
		
	# Limpieza de plataformas y monedas viejas
	for child in platforms_container.get_children():
		if child.global_position.y > camera.global_position.y + cleanup_threshold:
			child.queue_free()
	
	for child in get_children():
		if child.is_in_group("coin") and child.global_position.y > camera.global_position.y + cleanup_threshold:
			child.queue_free()
			
	# Detectar Game Over (caída fuera de cámara)
	if player.global_position.y > camera.global_position.y + 600:
		_game_over()

func _check_win_conditions() -> void:
	if win_condition_met: return

	var cond: int = config.get("win_condition", WinCondition.ALTURA)
	var target: float = config.get("target_value", 100.0)
	
	match cond:
		WinCondition.ALTURA:
			if max_score >= target:
				_win_game()
		WinCondition.MONEDAS:
			if coins_collected >= target:
				_win_game()

func _win_game() -> void:
	if win_condition_met:
		return
	win_condition_met = true
	set_process(false)
	AudioManager.play_ui(&"sfx_tramp_win")
	finish(true)

func _on_special_platform_reached() -> void:
	_win_game()

func _on_coin_collected() -> void:
	coins_collected += 1
	add_reward(Inventory.GOLD_ITEM_ID, 1)
	if config.get("win_condition") == WinCondition.MONEDAS:
		$UI/ScoreLabel.text = "Monedas: %d/%d" % [coins_collected, config.get("target_value")]

func spawn_platform() -> void:
	var new_plat: Node2D = PLATFORM_SCENE.instantiate()
	platforms_container.add_child(new_plat)
	
	# Posición aleatoria en el ancho del juego
	var x_pos: float = randf_range(-game_width/2.0 + 40, game_width/2.0 - 40)
	last_platform_y -= spawn_distance
	new_plat.global_position = Vector2(x_pos, last_platform_y)
	
	# Spawn de items coleccionables sobre la plataforma (siempre apoyados en ella)
	var item_chance = config.get("item_spawn_chance", 0.25)
	if not item_pool.is_empty() and randf() < item_chance:
		var chosen_id: String = pick_item_from_pool(item_pool)
		if not chosen_id.is_empty():
			_spawn_platform_item(chosen_id, Vector2(x_pos, last_platform_y - 25.0))
	
	# Spawn de monedas basado en densidad y patrones aleatorios (flotando en el aire)
	var density = config.get("coin_density", 0.3)
	if randf() < density:
		_spawn_coin_pattern(last_platform_y - 60.0)
	
	# Manejar plataforma especial si es la condición
	if config.get("win_condition") == WinCondition.ESPECIAL and not special_platform_spawned:
		var target_h = config.get("target_value", 100)
		var current_h = floor(-last_platform_y / 10.0)
		if current_h >= target_h:
			new_plat.modulate = Color.GOLD
			new_plat.add_to_group("special_platform")
			special_platform_spawned = true
			AudioManager.play_sfx(&"sfx_tramp_special_spawn")

func _spawn_platform_item(p_id: String, pos: Vector2) -> void:
	var item_node = ITEM_SCENE.instantiate() as MG_TrampolinItem
	var tex: Texture2D = get_item_icon(p_id)
	add_child(item_node)
	item_node.global_position = pos
	item_node.setup(p_id, tex)
	item_node.collected.connect(_on_platform_item_collected)

func _on_platform_item_collected(p_id: String) -> void:
	add_reward(p_id, 1)

func _game_over() -> void:
	set_process(false)
	AudioManager.play_ui(&"sfx_tramp_fall")
	AudioManager.play_ui(&"sfx_tramp_lose")
	finish(win_condition_met)

func spawn_base_floor() -> void:
	var start_y: float = last_platform_y + 100.0
	for x in range(-300, 301, 80):
		var base_plat = PLATFORM_SCENE.instantiate()
		platforms_container.add_child(base_plat)
		base_plat.global_position = Vector2(x, start_y)

func _spawn_coin_pattern(y_base: float) -> void:
	var pattern: int = randi() % 4
	var center_x: float = randf_range(-game_width/4.0, game_width/4.0)
	
	match pattern:
		CoinPattern.LINEA:
			for i in range(5):
				_spawn_one_coin(Vector2(center_x - 80 + i*40, y_base))
		CoinPattern.CUADRO:
			for row in range(4):
				for col in range(4):
					_spawn_one_coin(Vector2(center_x - 60 + col*40, y_base - row*40))
		CoinPattern.V:
			var offsets = [Vector2(-40, -40), Vector2(-20, -20), Vector2(0, 0), Vector2(20, -20), Vector2(40, -40)]
			for offset in offsets:
				_spawn_one_coin(Vector2(center_x, y_base) + offset)
		CoinPattern.V_INVERTIDA:
			var offsets = [Vector2(-40, 0), Vector2(-20, -20), Vector2(0, -40), Vector2(20, -20), Vector2(40, 0)]
			for offset in offsets:
				_spawn_one_coin(Vector2(center_x, y_base) + offset)

func _spawn_one_coin(pos: Vector2) -> void:
	var coin: Node2D = COIN_SCENE.instantiate()
	add_child(coin)
	coin.global_position = pos
	coin.collected.connect(_on_coin_collected)
