extends MinigameBase

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
var item_pool: Array = [] # Array[Dictionary]: [{"id": "blue_potion", "chance": 0.4, "is_critical": true}, ...]
var critical_item_ids: Array[String] = []

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
		if config.has("item_pool") and config["item_pool"] is Array:
			item_pool = config["item_pool"]
		if config.has("critical_item_ids") and config["critical_item_ids"] is Array:
			var c_ids: Array[String] = []
			for id in config["critical_item_ids"]:
				c_ids.append(str(id))
			critical_item_ids = c_ids
		
	time_left = target_value if game_mode == "TIME" else 0.0
	
	_update_ui()
	
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_rate
	spawn_timer.autostart = true
	spawn_timer.timeout.connect(_on_spawn_timeout)
	add_child(spawn_timer)
	
	# Floor area a la altura de los pies del jugador
	var floor_area = Area2D.new()
	floor_area.add_to_group("catcher_floor")
	var screen_size = get_viewport_rect().size
	floor_area.global_position = Vector2(screen_size.x / 2.0, 990.0)
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(screen_size.x + 200, 80)
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
	
	# Determinar si es un item del pool de inventario o si es crítico
	var chosen_item_id: String = ""
	var is_crit: bool = false
	var custom_texture: Texture2D = null
	
	if not is_bomb:
		# Evaluar si seleccionamos un item del pool
		if not item_pool.is_empty():
			if item_pool[0] is Dictionary:
				var roll = randf()
				var accum = 0.0
				for entry in item_pool:
					accum += entry.get("chance", 0.3)
					if roll <= accum:
						chosen_item_id = str(entry.get("id", ""))
						is_crit = entry.get("is_critical", false)
						break
			else:
				# Si es un Array de Strings (ej. ["blue_potion", "red_potion", "green_herb"])
				# 35% de probabilidad de que este punto caiga como ítem de inventario
				if randf() < 0.35:
					chosen_item_id = str(item_pool[randi() % item_pool.size()])
		
		# Si está explícitamente en la lista de críticos
		if not chosen_item_id.is_empty() and critical_item_ids.has(chosen_item_id):
			is_crit = true
		elif chosen_item_id.is_empty() and not critical_item_ids.is_empty():
			# Si no hay pool pero se especificó que los puntos normales son críticos
			if critical_item_ids.has("point"):
				is_crit = true
		
		var item_db = get_node_or_null("/root/ItemDatabase")
		if not chosen_item_id.is_empty() and item_db:
			var item_res = item_db.get_item(chosen_item_id)
			if item_res and item_res.icon:
				custom_texture = item_res.icon

	add_child(item)
	item.setup(base_fall_speed, Vector2(spawn_x, -50), is_crit, chosen_item_id, custom_texture)
	item.hit_floor.connect(func(_type): pass)
	item.expired.connect(_on_item_expired)
	item.caught.connect(func(type): _on_item_caught(type, item))
	
	# track active objects count
	item.tree_exited.connect(func(): active_objects -= 1)
	active_objects += 1

func _on_item_expired(is_crit: bool) -> void:
	if is_crit:
		# Si era un item crítico obligatorio y expiró en el suelo, se pierde vida
		lives -= 1
		print("[Catcher] ¡Objeto crítico perdido en el suelo! Vidas: ", lives)
		_update_ui()
		check_lives()
	else:
		print("[Catcher] Objeto no crítico expiró en el suelo.")

func _on_item_caught(item_type: int, item: FallingItemBase) -> void:
	if item_type == FallingItemBase.ItemType.POINT:
		score += 1
		if not item.item_id.is_empty():
			add_reward(item.item_id, 1)
			print("[Catcher] ¡Atrapado objeto especial: %s!" % item.item_id)
		else:
			add_reward("gold_coin", 1)
			print("[Catcher] Atrapado punto normal. Score: ", score)
			
		if game_mode == "COUNT" and score >= target_value:
			win()
	elif item_type == FallingItemBase.ItemType.BOMB:
		lives -= 1
		print("[Catcher] ¡Bomba atrapada! Vidas: ", lives)
		check_lives()
	_update_ui()

func check_lives() -> void:
	if lives <= 0:
		lose()

func win() -> void:
	if game_over: return
	game_over = true
	print("Catcher: WIN!")
	finish(true)

func lose() -> void:
	if game_over: return
	game_over = true
	print("Catcher: LOSE!")
	finish(false)
