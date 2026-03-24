extends Node2D

var platform_scene = load("res://scenes/minigames/mg_trampolin/mg_trampolin_platform.tscn")
var player_scene = load("res://scenes/minigames/mg_trampolin/mg_trampolin_player.tscn")
var coin_scene = load("res://scenes/minigames/mg_trampolin/mg_trampolin_coin.tscn")

@onready var camera = $Camera2D
@onready var platforms_container = $Platforms

var player: MG_TrampolinPlayer
var last_platform_y: float = 0.0
var spawn_distance: float = 120.0
var game_width: float = 600.0
var max_score: float = 0.0

@export var cleanup_threshold: float = 300.0

# Configuración y Estado
var config = {}
var coins_collected = 0
var win_condition_met = false
var special_platform_spawned = false

enum WinCondition { ALTURA, ESPECIAL, MONEDAS }
enum CoinPattern { LINEA, CUADRO, V, V_INVERTIDA }

func _ready():
	config = GameManager.minigame_config
	print("Trampolin iniciado con config:", config)
	
	# Configuración inicial del juego
	last_platform_y = get_viewport_rect().size.y - 100.0
	
	# Spawn del jugador
	player = player_scene.instantiate()
	add_child(player)
	player.global_position = Vector2(0, last_platform_y - 50.0)
	player.died.connect(_on_player_died)
	
	# Centrar cámara en el jugador inicial
	camera.make_current()
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
	
	if win_condition_met:
		if Input.is_anything_pressed():
			GameManager.return_to_overworld()
		
	# Actualizar Score basado en la altura máxima alcanzada (Y negativa)
	var current_score = floor(-player.global_position.y / 10.0)
	if current_score > max_score:
		max_score = current_score
		$UI/ScoreLabel.text = "Score: " + str(max_score)
	
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

func _check_win_conditions():
	if win_condition_met: return
	
	var cond = config.get("win_condition", WinCondition.ALTURA)
	var target = config.get("target_value", 100)
	
	match cond:
		WinCondition.ALTURA:
			if max_score >= target:
				_win_game("¡Altura alcanzada!")
		WinCondition.MONEDAS:
			if coins_collected >= target:
				_win_game("¡Monedas recolectadas!")

func _win_game(reason: String):
	win_condition_met = true
	print("VICTORIA: ", reason)
	
	# Mostrar cartel de victoria
	var win_label = Label.new()
	win_label.text = "¡GANASTE!\n" + reason + "\n\nPresiona cualquier tecla para salir"
	win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	win_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win_label.modulate = Color.YELLOW
	win_label.add_theme_font_size_override("font_size", 48)
	
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$UI.add_child(bg)
	$UI.add_child(win_label)

func _on_coin_collected():
	coins_collected += 1
	PlayerStats.add_gold(1)
	print("Monedas: ", coins_collected)
	if config.get("win_condition") == WinCondition.MONEDAS:
		$UI/ScoreLabel.text = "Monedas: %d/%d" % [coins_collected, config.get("target_value")]

func spawn_platform():
	var new_plat = platform_scene.instantiate()
	platforms_container.add_child(new_plat)
	
	# Posición aleatoria en el ancho del juego
	var x_pos = randf_range(-game_width/2.0 + 40, game_width/2.0 - 40)
	last_platform_y -= spawn_distance
	new_plat.global_position = Vector2(x_pos, last_platform_y)
	
	# Spawn de monedas basado en densidad y patrones aleatorios
	var density = config.get("coin_density", 0.3)
	if randf() < density:
		_spawn_coin_pattern(last_platform_y - 60.0)
	
	# Manejar plataforma especial si es la condición
	if config.get("win_condition") == WinCondition.ESPECIAL and not special_platform_spawned:
		var target_h = config.get("special_height", 300)
		var current_h = floor(-last_platform_y / 10.0)
		if current_h >= target_h:
			new_plat.modulate = Color.GOLD
			new_plat.add_to_group("special_platform")
			special_platform_spawned = true
			print("Plataforma especial aparecida a altura: ", current_h)

func _on_player_died():
	_game_over()

func _game_over():
	print("GAME OVER - Trampolin")
	set_process(false)
	get_tree().create_timer(1.0).timeout.connect(func():
		GameManager.return_to_overworld()
	)

func spawn_base_floor():
	var start_y = last_platform_y + 100.0
	for x in range(-300, 301, 80):
		var base_plat = platform_scene.instantiate()
		platforms_container.add_child(base_plat)
		base_plat.global_position = Vector2(x, start_y)

func _spawn_coin_pattern(y_base: float):
	var pattern = randi() % 4
	var center_x = randf_range(-game_width/4.0, game_width/4.0)
	
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

func _spawn_one_coin(pos: Vector2):
	var coin = coin_scene.instantiate()
	add_child(coin)
	coin.global_position = pos
	coin.collected.connect(_on_coin_collected)
