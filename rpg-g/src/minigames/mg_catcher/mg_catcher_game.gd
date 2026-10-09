extends MinigameBase

@export var point_scene: PackedScene = preload("res://src/minigames/mg_catcher/falling_item_point.tscn")
@export var bomb_scene: PackedScene = preload("res://src/minigames/mg_catcher/falling_item_bomb.tscn")

# UI References
@onready var score_label = $UI/HUD/ScoreLabel
@onready var time_label = $UI/HUD/TimeLabel
@onready var lives_label = $UI/HUD/LivesLabel

var base_fall_speed: float = 200.0
var spawn_rate: float = 1.0
var max_falling_objects: int = 10
## Segundos que los objetos que no matan quedan en el suelo antes de desaparecer.
var floor_wait_time: float = 3.0
var game_mode: String = "TIME"
var target_value: float = 30.0
var item_pool: Array = []
var critical_item_ids: Array[String] = []

var score: int = 0
var lives: int = 3
var time_left: float = 0.0
var game_over: bool = false
var active_objects: int = 0

var spawn_timer: Timer = null

func _ready() -> void:
	var config = GameManager.minigame_config
	if config:
		base_fall_speed = config.get("base_fall_speed", 200.0)
		spawn_rate = config.get("spawn_rate", 1.0)
		max_falling_objects = config.get("max_falling_objects", 10)
		floor_wait_time = config.get("floor_wait_time", 3.0)
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
			AudioManager.play_ui(&"sfx_catch_time_up")
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
				chosen_item_id = pick_item_from_pool(item_pool)
				is_crit = _is_pool_entry_critical(chosen_item_id)
			elif randf() < 0.35:
				# Si es un Array de Strings (ej. ["blue_potion", "red_potion", "green_herb"])
				# 35% de probabilidad de que este punto caiga como ítem de inventario
				chosen_item_id = pick_item_from_pool(item_pool)
		
		# Si está explícitamente en la lista de críticos
		if not chosen_item_id.is_empty() and critical_item_ids.has(chosen_item_id):
			is_crit = true
		elif chosen_item_id.is_empty() and not critical_item_ids.is_empty():
			# Si no hay pool pero se especificó que los puntos normales son críticos
			if critical_item_ids.has("point"):
				is_crit = true
		
		if not chosen_item_id.is_empty():
			custom_texture = get_item_icon(chosen_item_id)

	add_child(item)
	AudioManager.play_sfx(&"sfx_catch_spawn")
	item.setup(base_fall_speed, Vector2(spawn_x, -50), is_crit, chosen_item_id, custom_texture, floor_wait_time)
	item.hit_floor.connect(func(_type): pass)
	item.expired.connect(_on_item_expired)
	item.caught.connect(func(type): _on_item_caught(type, item))
	
	# track active objects count
	item.tree_exited.connect(func(): active_objects -= 1)
	active_objects += 1

## Indica si la entrada del pool (formato Dictionary) con ese id está marcada como crítica.
func _is_pool_entry_critical(entry_id: String) -> bool:
	if entry_id.is_empty():
		return false
	for entry: Variant in item_pool:
		if entry is Dictionary and str(entry.get("id", "")) == entry_id:
			return bool(entry.get("is_critical", false))
	return false

func _on_item_expired(is_crit: bool) -> void:
	if is_crit:
		# Si era un item crítico obligatorio y expiró en el suelo, se pierde vida
		AudioManager.play_sfx(&"sfx_catch_miss")
		_lose_life()
		_update_ui()
		check_lives()

func _on_item_caught(item_type: int, item: FallingItemBase) -> void:
	if item_type == FallingItemBase.ItemType.POINT:
		score += 1
		AudioManager.play_sfx(&"sfx_catch_item")
		if not item.item_id.is_empty():
			add_reward(item.item_id, 1)
		else:
			add_reward(Inventory.GOLD_ITEM_ID, 1)

		if game_mode == "COUNT" and score >= target_value:
			AudioManager.play_ui(&"sfx_catch_win")
			win()
	elif item_type == FallingItemBase.ItemType.BOMB:
		AudioManager.play_sfx(&"sfx_catch_bomb")
		_lose_life()
		check_lives()
	_update_ui()

func _lose_life() -> void:
	lives -= 1
	AudioManager.play_sfx(&"sfx_catch_life_lost")

func check_lives() -> void:
	if lives <= 0:
		lose()

func win() -> void:
	if game_over: return
	game_over = true
	finish(true)

func lose() -> void:
	if game_over: return
	game_over = true
	AudioManager.play_ui(&"sfx_catch_lose")
	finish(false)
