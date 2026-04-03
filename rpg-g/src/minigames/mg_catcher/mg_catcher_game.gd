extends Node2D

@export var point_scene: PackedScene = preload("res://src/minigames/mg_catcher/falling_item_point.tscn")
@export var bomb_scene: PackedScene = preload("res://src/minigames/mg_catcher/falling_item_bomb.tscn")

# UI References
@onready var score_label = $UI/HUD/ScoreLabel
@onready var time_label = $UI/HUD/TimeLabel
@onready var lives_label = $UI/HUD/LivesLabel
@onready var message_overlay = $UI/MessageOverlay
@onready var message_label = $UI/MessageOverlay/Label

var base_fall_speed: float = 200.0
var spawn_rate: float = 1.0
var max_falling_objects: int = 10
var game_mode: String = "TIME" # "TIME" or "COUNT"
var target_value: float = 30.0

var score: int = 0
var lives: int = 3
var time_left: float = 0.0
var game_over: bool = false
var active_objects: int = 0

var spawn_timer: Timer

func _ready() -> void:
	var config = GameManager.minigame_config
	if config:
		base_fall_speed = config.get("base_fall_speed", 200.0)
		spawn_rate = config.get("spawn_rate", 1.0)
		max_falling_objects = config.get("max_falling_objects", 10)
		game_mode = config.get("game_mode", "TIME")
		target_value = config.get("target_value", 30.0)
		lives = config.get("lives", 3)
		
	time_left = target_value if game_mode == "TIME" else 0.0
	
	_update_ui()
	
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_rate
	spawn_timer.autostart = true
	spawn_timer.timeout.connect(_on_spawn_timeout)
	add_child(spawn_timer)
	
	# We need a floor area to catch missed items
	var floor_area = Area2D.new()
	floor_area.add_to_group("catcher_floor")
	var screen_size = get_viewport_rect().size
	floor_area.global_position = Vector2(screen_size.x / 2.0, screen_size.y + 50)
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(screen_size.x + 200, 100)
	shape.shape = rect
	floor_area.add_child(shape)
	add_child(floor_area)

func _process(delta: float) -> void:
	if game_over: return
	
	if game_mode == "TIME":
		time_left -= delta
		if time_left <= 0 and lives > 0:
			time_left = 0
			win()
			
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
	if game_over or active_objects >= max_falling_objects: return
	
	var is_bomb = randf() < 0.3 # 30% chance of bomb
	var scene = bomb_scene if is_bomb else point_scene
	var item = scene.instantiate() as FallingItemBase
	
	var screen_size = get_viewport_rect().size
	var spawn_x = randf_range(50, screen_size.x - 50)
	
	add_child(item)
	item.setup(base_fall_speed, Vector2(spawn_x, -50))
	item.hit_floor.connect(_on_item_hit_floor)
	item.caught.connect(_on_item_caught)
	
	# track active objects count
	item.tree_exited.connect(func(): active_objects -= 1)
	active_objects += 1

func _on_item_hit_floor(item_type: int) -> void:
	if item_type == FallingItemBase.ItemType.POINT:
		# Missed a point item = lose life
		lives -= 1
		print("Missed point item! Lives: ", lives)
		check_lives()
	# Bomb hitting floor = nothing happens

func _on_item_caught(item_type: int) -> void:
	if item_type == FallingItemBase.ItemType.POINT:
		score += 1
		print("Caught point item! Score: ", score)
		if game_mode == "COUNT" and score >= target_value:
			win()
	elif item_type == FallingItemBase.ItemType.BOMB:
		lives -= 1
		print("Caught bomb! Lives: ", lives)
		check_lives()

func check_lives() -> void:
	if lives <= 0:
		lose()

func win() -> void:
	if game_over: return
	game_over = true
	if message_overlay:
		message_overlay.show()
		message_label.text = "¡VICTORIA!"
	print("Catcher: WIN!")
	finish_game()

func lose() -> void:
	if game_over: return
	game_over = true
	if message_overlay:
		message_overlay.show()
		message_label.text = "GAME OVER"
	print("Catcher: LOSE!")
	finish_game()

func finish_game() -> void:
	await get_tree().create_timer(1.0).timeout
	GameManager.return_to_overworld()
