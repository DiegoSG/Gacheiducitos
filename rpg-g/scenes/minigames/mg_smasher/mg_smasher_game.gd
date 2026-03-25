extends Node2D

# Configurable paths
@export var insect_scene: PackedScene = preload("res://scenes/minigames/mg_smasher/insect.tscn")

# State
var initial_speed: float = 100.0
var final_speed: float = 400.0
var current_speed: float = 100.0
var num_holes: int = 6
var game_mode: String = "TIME" # "TIME" or "COUNT"
var target_value: float = 30.0 # seconds or kill count
var escape_limit: int = 5

var score: int = 0
var escaped_count: int = 0
var time_left: float = 0.0
var game_over: bool = false

var holes: Array[Vector2] = []
var spawn_timer: Timer

func _ready() -> void:
	# Load config from GameManager
	var config = GameManager.minigame_config
	if config:
		initial_speed = config.get("initial_speed", 100.0)
		final_speed = config.get("final_speed", 400.0)
		num_holes = config.get("num_holes", 6)
		game_mode = config.get("game_mode", "TIME")
		target_value = config.get("target_value", 30.0)
		escape_limit = config.get("escape_limit", 5)
	
	current_speed = initial_speed
	time_left = target_value if game_mode == "TIME" else 0.0
	
	setup_game()

func setup_game() -> void:
	# Define hole positions along the screen edges
	var screen_size = get_viewport_rect().size
	var margin = 20.0
	
	for i in range(num_holes):
		var t = float(i) / num_holes
		var pos = Vector2.ZERO
		if t < 0.25: # TOP
			pos = Vector2(lerp(margin, screen_size.x - margin, t * 4), margin)
		elif t < 0.5: # RIGHT
			pos = Vector2(screen_size.x - margin, lerp(margin, screen_size.y - margin, (t - 0.25) * 4))
		elif t < 0.75: # BOTTOM
			pos = Vector2(lerp(screen_size.x - margin, margin, (t - 0.5) * 4), screen_size.y - margin)
		else: # LEFT
			pos = Vector2(margin, lerp(screen_size.y - margin, margin, (t - 0.75) * 4))
		holes.append(pos)
	
	# Setup spawn timer
	spawn_timer = Timer.new()
	spawn_timer.wait_time = 1.0
	spawn_timer.autostart = true
	spawn_timer.timeout.connect(_on_spawn_timeout)
	add_child(spawn_timer)
	
	print("Smasher initialized: ", game_mode, " target: ", target_value)

func _process(delta: float) -> void:
	if game_over:
		return
		
	if game_mode == "TIME":
		time_left -= delta
		if time_left <= 0:
			win()
	
	# Gradually increase speed
	if current_speed < final_speed:
		current_speed += (final_speed - initial_speed) / 60.0 * delta # Reach max in ~60s
	
	# Difficulty: spawn faster as speed increases
	spawn_timer.wait_time = max(0.3, 1.2 - (current_speed - initial_speed) / (final_speed - initial_speed) * 0.9)

func _on_spawn_timeout() -> void:
	if game_over:
		return
	spawn_insect()

func spawn_insect() -> void:
	if holes.size() < 2:
		return
		
	var start_idx = randi() % holes.size()
	# Ensure end hole is different and not adjacent if possible for longer paths
	var end_idx = (start_idx + holes.size() / 2 + (randi() % 2)) % holes.size()
	
	var insect = insect_scene.instantiate()
	add_child(insect)
	insect.setup(holes[start_idx], holes[end_idx], current_speed)
	insect.smashed.connect(_on_insect_smashed)
	insect.escaped.connect(_on_insect_escaped)

func _on_insect_smashed() -> void:
	score += 1
	print("Score: ", score)
	if game_mode == "COUNT" and score >= target_value:
		win()

func _on_insect_escaped() -> void:
	escaped_count += 1
	print("Escaped: ", escaped_count)
	if escaped_count >= escape_limit:
		lose()

func win() -> void:
	game_over = true
	print("Smasher: WIN!")
	finish_game()

func lose() -> void:
	game_over = true
	print("Smasher: LOSE!")
	finish_game()

func finish_game() -> void:
	# Visual feedback or UI could be added here
	await get_tree().create_timer(1.0).timeout
	GameManager.return_to_overworld()
