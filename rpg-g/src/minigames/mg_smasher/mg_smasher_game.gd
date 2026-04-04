extends Node2D

# Configurable paths
@export var insect_scene: PackedScene = preload("res://src/minigames/mg_smasher/insect.tscn")

# UI References
@onready var score_label = $UI/HUD/ScoreLabel
@onready var time_label = $UI/HUD/TimeLabel
@onready var lives_label = $UI/HUD/LivesLabel
@onready var message_overlay = $UI/MessageOverlay
@onready var message_label = $UI/MessageOverlay/Label

# State
var initial_speed: float = 100.0
var final_speed: float = 400.0
var current_speed: float = 100.0
var num_spawn_points: int = 8
var bugs_per_spawn: int = 1
var game_mode: String = "TIME" # "TIME" or "COUNT"
var target_value: float = 30.0 # seconds or kill count
var lives: int = 3

var score: int = 0
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
		num_spawn_points = clamp(config.get("num_spawn_points", 8), 8, 32)
		bugs_per_spawn = config.get("bugs_per_spawn", 1)
		game_mode = config.get("game_mode", "TIME")
		target_value = config.get("target_value", 30.0)
	
	current_speed = initial_speed
	time_left = target_value if game_mode == "TIME" else 0.0
	lives = config.get("lives", 3)
	
	setup_game()
	_update_ui()

func setup_game() -> void:
	# Define hole positions along the screen edges
	var screen_size = get_viewport_rect().size
	var margin = 20.0
	
	for i in range(num_spawn_points):
		var t = float(i) / num_spawn_points
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
		
		# Visual feedback for holes
		var marker = ColorRect.new()
		marker.size = Vector2(10, 10)
		marker.position = pos - Vector2(5, 5)
		marker.color = Color(0.2, 0.1, 0.1, 0.5)
		add_child(marker)
	
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
		if time_left <= 0 and lives > 0:
			time_left = 0
			win()
	
	# Gradually increase speed
	if current_speed < final_speed:
		current_speed += (final_speed - initial_speed) / 60.0 * delta # Reach max in ~60s
	
	# Difficulty: spawn faster as speed increases
	spawn_timer.wait_time = max(0.3, 1.2 - (current_speed - initial_speed) / (final_speed - initial_speed) * 0.9)
	
	_update_ui()

func _update_ui() -> void:
	if score_label: score_label.text = "Score: %d" % score
	if time_label: 
		if game_mode == "TIME":
			time_label.text = "Time: %.1f" % time_left
		else:
			time_label.text = "Target: %d" % target_value
	if lives_label: lives_label.text = "Lives: %d" % lives

func _on_spawn_timeout() -> void:
	if game_over:
		return
	spawn_insect()

func spawn_insect() -> void:
	if holes.size() < 2:
		return
		
	var available_starts = []
	for i in range(holes.size()):
		available_starts.append(i)
	available_starts.shuffle()
	
	var to_spawn = min(bugs_per_spawn, available_starts.size())
	for i in range(to_spawn):
		var start_idx = available_starts[i]
		# Ensure end hole is roughly on the opposite side
		var end_idx = (start_idx + holes.size() / 2 + (randi() % 3 - 1)) % holes.size()
		# Make sure end != start
		if start_idx == end_idx:
			end_idx = (start_idx + 1) % holes.size()
		
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
	lives -= 1
	print("Life lost! Lives remaining: ", lives)
	if lives <= 0:
		lose()

func win() -> void:
	game_over = true
	if message_overlay:
		message_overlay.show()
		message_label.text = "¡VICTORIA!"
	print("Smasher: WIN!")
	finish_game()

func lose() -> void:
	game_over = true
	if message_overlay:
		message_overlay.show()
		message_label.text = "GAME OVER"
	print("Smasher: LOSE!")
	finish_game()

func finish_game() -> void:
	# Visual feedback or UI could be added here
	await get_tree().create_timer(1.0).timeout
	GameManager.return_to_overworld()
