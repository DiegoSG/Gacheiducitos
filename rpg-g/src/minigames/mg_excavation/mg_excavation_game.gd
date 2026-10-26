extends MinigameBase
class_name MG_ExcavationGame

# Reference to shared types
const MGT = preload("res://src/minigames/mg_excavation/mg_excavation_types.gd")
const TileType = MGT.TileType
const WinCondition = MGT.WinCondition

# Grid configuration
const CELL_SIZE: int = 16
var grid_width: int = 40
var grid_height: int = 23

# Tile grid (2D Array)
var grid: Array = []

# Reference to the player
var player_grid_pos: Vector2i = Vector2i(1, 1)
var is_player_dead: bool = false

# Mission state
var total_coins: int = 0
var coins_collected: int = 0
var mission_item_collected: bool = false
var current_win_condition: int = WinCondition.ALL_COINS
var target_coin_amount: int = 0
# If false, the minigame is won as soon as the goal is met, without walking to the exit
var require_exit: bool = true

# Configuration received from the debug screen
var config: Dictionary = {}

# Gravity system
var gravity_timer: float = 0.0
const GRAVITY_TICK: float = 0.12 # Same delay as player movement

# Minimum interval between footstep sounds
const STEP_SOUND_INTERVAL: float = 0.25
var _step_sound_cooldown: float = 0.0

# Reason _explode_at uses when chaining the explosion of other bombs
const CHAIN_EXPLOSION_REASON: String = "EXPLOSIÓN EN CADENA"

# Continuous movement system
var move_timer: float = 0.0
const MOVE_DELAY: float = 0.12
var current_direction: Vector2i = Vector2i.ZERO

# Rock pushing and visuals system
var is_pushing_rock: bool = false
const PUSH_DELAY: float = 0.24 # Half speed when pushing
var falling_visuals: Dictionary = {} # "x,y" -> { "visual_pos": Vector2, "rotation": float, "type": int }
var falling_objects: Dictionary = {} # "x,y" -> true (coordinates of objects that were already falling)
var pending_falls: Dictionary = {} # "x,y" -> ticks_remaining (objects that want to start falling)

# Bomb system
var player_bombs_ammo: int = 0
var space_held_timer: float = 0.0
const BOMB_PLANT_HOLD_TIME: float = 0.35
var active_placed_bombs: Array = [] # Array[Dictionary]: [{"pos": Vector2i, "timer": 4.0}]
var deliver_items: bool = false
var item_pool: Array = []
# Specific rewards of hand-placed items: Vector2i -> {"id": String, "amount": int}
var cell_items: Dictionary = {}

# Textures
var coin_texture: Texture2D = null
var bomb_texture: Texture2D = null
var potion_texture: Texture2D = null
var player_texture: Texture2D = null

# Smooth interpolation system
var visual_player_pos: Vector2 = Vector2.ZERO
var interp_speed: float = 15.0

# Refined input handling
var input_stack: Array = [] # List of pressed directions, in order

# Camera
var camera: Camera2D = null

# HUD on its own CanvasLayer so it stays on screen while the camera scrolls the level
const HUD_FONT_SIZE: int = 18
var hud_label: Label = null

func _ready() -> void:
	# Shared coin texture (with fallback) from MinigameBase
	coin_texture = get_coin_texture()
	bomb_texture = load("res://assets/items/icons/iron_key.png") as Texture2D
	potion_texture = load("res://assets/items/icons/blue_potion.png") as Texture2D
	player_texture = load("res://assets/sprites/player_down.png") as Texture2D

	config = GameManager.minigame_config
	
	deliver_items = config.get("deliver_items", false)
	player_bombs_ammo = config.get("initial_bombs", 1)
	if config.has("item_pool") and config["item_pool"] is Array:
		item_pool = config["item_pool"]
	else:
		item_pool = ["blue_potion", "red_potion", "green_herb"]
	
	# Apply global scale
	var s = config.get("escala", 1.5)
	self.scale = Vector2(s, s)
	
	# Initialize mission state from config
	current_win_condition = config.get("win_condition", WinCondition.ALL_COINS)
	target_coin_amount = config.get("target_amount", 5)
	# Reaching the exit is the whole goal of EXIT_ONLY, so it can never be skipped
	require_exit = config.get("require_exit", true) or current_win_condition == WinCondition.EXIT_ONLY

	_load_level()
	_count_total_coins()
	
	# Initialize visual positions
	visual_player_pos = grid_to_world(player_grid_pos)
	_initialize_falling_visuals()
	
	# Set up camera
	_setup_camera()
	_setup_hud()
	
	AudioManager.play_sfx(&"sfx_exc_start")
	queue_redraw()

func _setup_camera() -> void:
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	
	# Set camera limits (2 extra tiles of margin)
	# Uses global_position in case the root node is not at (0,0)
	var s = self.scale.x
	var margin = 2 * CELL_SIZE
	var origin = self.global_position
	
	camera.limit_left = int(origin.x - (margin * s))
	camera.limit_top = int(origin.y - (margin * s))
	camera.limit_right = int(origin.x + (grid_width * CELL_SIZE + margin) * s)
	camera.limit_bottom = int(origin.y + (grid_height * CELL_SIZE + margin) * s)
	
	# Camera smoothing so it doesn't jerk with the interpolation
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 10.0
	
	_update_camera_position()

func _setup_hud() -> void:
	var hud_layer: CanvasLayer = CanvasLayer.new()
	hud_layer.name = "HudLayer"
	add_child(hud_layer)
	hud_label = Label.new()
	hud_label.position = Vector2(16, 12)
	hud_label.add_theme_font_size_override("font_size", HUD_FONT_SIZE)
	hud_label.add_theme_constant_override("outline_size", 4)
	hud_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hud_layer.add_child(hud_label)

func _update_camera_position() -> void:
	if camera:
		# The camera position must be relative to the global world
		# visual_player_pos is in the grid's local coordinates
		camera.global_position = self.global_position + (visual_player_pos * self.scale)

func _initialize_falling_visuals() -> void:
	falling_visuals.clear()
	for y in range(grid_height):
		for x in range(grid_width):
			var tile = grid[y][x]
			if tile == TileType.PIEDRA or tile == TileType.ITEM_RECOMPENSA or tile == TileType.BOMBA:
				var key = str(x) + "," + str(y)
				falling_visuals[key] = {
					"visual_pos": grid_to_world(Vector2i(x,y)),
					"rotation": 0.0,
					"type": tile
				}

func _process(delta: float) -> void:
	if is_player_dead:
		_interpolate_visuals(delta) # Keep interpolating even when dead so the impact can be seen
		queue_redraw()
		return

	# Process countdown of bombs placed by the player
	_update_placed_bombs(delta)

	# Process bomb planting while space is held
	_handle_bomb_planting(delta)

	gravity_timer += delta
	if gravity_timer >= GRAVITY_TICK:
		gravity_timer = 0.0
		_update_gravity()

	if not is_player_dead:
		_handle_continuous_movement(delta)

	_interpolate_visuals(delta)
	_update_camera_position()
	queue_redraw()

func _handle_bomb_planting(delta: float) -> void:
	if Input.is_action_pressed("plant_bomb"):
		if current_direction == Vector2i.ZERO:
			if space_held_timer >= 0.0:
				space_held_timer += delta
				if space_held_timer >= BOMB_PLANT_HOLD_TIME:
					space_held_timer = -1.0
					_try_plant_bomb()
		else:
			space_held_timer = 0.0
	else:
		space_held_timer = 0.0

func _try_plant_bomb() -> void:
	if player_bombs_ammo <= 0:
		return
	
	# Check whether there is already a bomb at the player's position
	for b in active_placed_bombs:
		if b.pos == player_grid_pos:
			return
			
	player_bombs_ammo -= 1
	active_placed_bombs.append({
		"pos": player_grid_pos,
		"timer": 4.0
	})
	AudioManager.play_sfx(&"sfx_exc_bomb_plant")
	AudioManager.play_sfx(&"sfx_exc_bomb_fuse")
	queue_redraw()

func _update_placed_bombs(delta: float) -> void:
	# Iterate over a copy: _explode_at removes the bombs caught in its radius from the real list
	for b in active_placed_bombs.duplicate():
		if not active_placed_bombs.has(b):
			continue
		b.timer -= delta
		if b.timer <= 0.0:
			active_placed_bombs.erase(b)
			_explode_at(b.pos, "BOMBA MANUAL")

func _explode_at(center_pos: Vector2i, _reason: String = "EXPLOSIÓN") -> void:
	AudioManager.play_sfx(&"sfx_exc_chain_explosion" if _reason == CHAIN_EXPLOSION_REASON else &"sfx_exc_explosion")
	# Destroy 3x3 area
	var player_caught = false
	var chain_explosions: Array[Vector2i] = []
	
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var tx = center_pos.x + dx
			var ty = center_pos.y + dy
			if _in_bounds(Vector2i(tx, ty)):
				var t = grid[ty][tx]
				# Chain if there is another ambient bomb
				if (dx != 0 or dy != 0) and t == TileType.BOMBA:
					chain_explosions.append(Vector2i(tx, ty))
					
				# The exit and indestructible borders are immune
				if t != TileType.SALIDA and t != TileType.MURO_IRROMPIBLE:
					grid[ty][tx] = TileType.EMPTY
					var key = str(tx) + "," + str(ty)
					if falling_visuals.has(key):
						falling_visuals.erase(key)
				if player_grid_pos == Vector2i(tx, ty):
					player_caught = true
					
	# Remove manual bombs trapped in the explosion radius
	var remaining_bombs: Array = []
	for b in active_placed_bombs:
		if abs(b.pos.x - center_pos.x) <= 1 and abs(b.pos.y - center_pos.y) <= 1:
			pass
		else:
			remaining_bombs.append(b)
	active_placed_bombs = remaining_bombs
	
	queue_redraw()
	
	# Run chain explosions
	for next_bomb in chain_explosions:
		_explode_at(next_bomb, CHAIN_EXPLOSION_REASON)
	
	if player_caught:
		_player_crushed()

func _interpolate_visuals(delta: float) -> void:
	# Interpolate player
	var target_player_world = grid_to_world(player_grid_pos)
	visual_player_pos = visual_player_pos.lerp(target_player_world, interp_speed * delta)
	
	# Interpolate rocks and objects
	for key in falling_visuals:
		var data = falling_visuals[key]
		var coords = key.split(",")
		var target_world = grid_to_world(Vector2i(int(coords[0]), int(coords[1])))
		data.visual_pos = data.visual_pos.lerp(target_world, interp_speed * delta)

func _handle_continuous_movement(delta: float) -> void:
	_step_sound_cooldown = maxf(0.0, _step_sound_cooldown - delta)
	_prune_released_directions()
	var direction: Vector2i = Vector2i.ZERO
	
	if input_stack.size() > 0:
		direction = input_stack[-1] # Use the last key pressed
	
	if direction != current_direction:
		current_direction = direction
		move_timer = 0.0
		is_pushing_rock = false
		
		if direction != Vector2i.ZERO:
			_handle_player_action(direction)
	
	if current_direction != Vector2i.ZERO:
		move_timer += delta
		var delay = PUSH_DELAY if is_pushing_rock else MOVE_DELAY
		
		if move_timer >= delay:
			move_timer = 0.0
			_handle_player_action(current_direction)

func _handle_player_action(direction: Vector2i) -> void:
	if Input.is_action_pressed("plant_bomb"):
		_try_dig_adjacent(direction)
	else:
		_try_move_player(direction)

## Loads the painted level from config "level_scene", or generates a procedural one.
func _load_level() -> void:
	var data: ExcavationLevelData = null
	var level_scene: String = str(config.get("level_scene", ""))
	if not level_scene.is_empty():
		data = ExcavationLevelLoader.load_scene(level_scene)
		if data == null:
			push_warning("MG_ExcavationGame: falling back to a procedural level.")
	if data == null:
		data = LevelGenerator.generate_level(grid_width, grid_height, config)

	grid = data.grid
	grid_width = data.size.x
	grid_height = data.size.y
	player_grid_pos = data.player_start
	cell_items = data.cell_items
	if not data.item_pool.is_empty():
		item_pool = data.item_pool

func _count_total_coins() -> void:
	total_coins = 0
	for y in range(grid_height):
		for x in range(grid_width):
			if grid[y][x] == TileType.ITEM_RECOMPENSA:
				total_coins += 1
	if current_win_condition == WinCondition.ALL_COINS:
		target_coin_amount = total_coins
	elif current_win_condition == WinCondition.TARGET_AMOUNT and target_coin_amount > total_coins:
		push_warning("MG_ExcavationGame: target_amount %d is above the %d coins in the level; using %d." % [target_coin_amount, total_coins, total_coins])
		target_coin_amount = total_coins

func _draw():
	# 1. Uniform base background for the whole level (avoids "gaps" under the rocks)
	var total_size = Vector2(grid_width * CELL_SIZE, grid_height * CELL_SIZE)
	draw_rect(Rect2(Vector2.ZERO, total_size), Color(0.1, 0.1, 0.15))

	for y in range(grid_height):
		for x in range(grid_width):
			var tile = grid[y][x]
			var pos = Vector2(x * CELL_SIZE, y * CELL_SIZE)
			
			# Draw subtle grid
			draw_rect(Rect2(pos, Vector2(CELL_SIZE, CELL_SIZE)), Color(0, 0, 0, 0.1), false, 1)
			
			var color = _get_tile_color(tile)
			# Only draw content if it is not empty or transparent (rocks/player are drawn later)
			if color != Color.TRANSPARENT and tile != TileType.EMPTY:
				draw_rect(Rect2(pos, Vector2(CELL_SIZE, CELL_SIZE)), color)
				draw_rect(Rect2(pos, Vector2(CELL_SIZE, CELL_SIZE)), Color(0, 0, 0, 0.2), false, 1)
				
				# Details for pickups that replace dirt
				if tile == TileType.BOMB_PICKUP:
					draw_circle(pos + Vector2(CELL_SIZE/2.0, CELL_SIZE/2.0), CELL_SIZE/3.5, Color(0.05, 0.05, 0.05))
					draw_circle(pos + Vector2(CELL_SIZE/2.0 + 2, CELL_SIZE/2.0 - 2), 2, Color.RED)
				elif tile == TileType.ITEM_INVENTARIO:
					if potion_texture:
						draw_texture_rect(potion_texture, Rect2(pos + Vector2(2, 2), Vector2(CELL_SIZE - 4, CELL_SIZE - 4)), false)
					else:
						draw_circle(pos + Vector2(CELL_SIZE/2.0, CELL_SIZE/2.0), CELL_SIZE/3.0, Color(0.9, 0.4, 0.9))
	
	# Draw player using visual position
	if player_texture:
		var draw_p = visual_player_pos - Vector2(CELL_SIZE/2.0, CELL_SIZE/2.0)
		draw_texture_rect(player_texture, Rect2(draw_p, Vector2(CELL_SIZE, CELL_SIZE)), false)
	else:
		draw_rect(Rect2(visual_player_pos - Vector2(CELL_SIZE/2.0, CELL_SIZE/2.0), Vector2(CELL_SIZE, CELL_SIZE)), Color.YELLOW)
		draw_circle(visual_player_pos, CELL_SIZE/3.0, Color.ORANGE)
	
	# Bomb planting indicator (space held)
	if space_held_timer > 0.0 and player_bombs_ammo > 0:
		var progress = clamp(space_held_timer / BOMB_PLANT_HOLD_TIME, 0.0, 1.0)
		draw_arc(visual_player_pos, CELL_SIZE * 0.75, 0.0, TAU * progress, 16, Color(1.0, 0.2, 0.2, 0.9), 2.5)
	
	# Draw rocks and objects using visual position and rotation
	for key in falling_visuals:
		var data = falling_visuals[key]
		var pos = data.visual_pos
		var rot = data.rotation
		
		draw_set_transform(pos, rot, Vector2.ONE)
		if data.type == TileType.PIEDRA:
			draw_rect(Rect2(-CELL_SIZE/2.0 + 1, -CELL_SIZE/2.0 + 1, CELL_SIZE - 2, CELL_SIZE - 2), Color(0.5, 0.5, 0.5))
			# Detail to show the rotation
			draw_rect(Rect2(-CELL_SIZE/2.0 + 3, -CELL_SIZE/2.0 + 3, 4, 4), Color(0.7, 0.7, 0.7)) 
		elif data.type == TileType.BOMBA:
			# Ambient bomb (dark circle with fuse)
			draw_circle(Vector2.ZERO, CELL_SIZE/2.0 - 2, Color(0.1, 0.1, 0.1))
			draw_circle(Vector2.ZERO, CELL_SIZE/4.0, Color(0.25, 0.25, 0.25))
			draw_circle(Vector2(0, -CELL_SIZE/3.0), 2.5, Color(1.0, 0.3, 0.1))
		elif data.type == TileType.ITEM_RECOMPENSA:
			draw_texture_rect(coin_texture, Rect2(-CELL_SIZE/2.0, -CELL_SIZE/2.0, CELL_SIZE, CELL_SIZE), false)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	
	# Draw manual bombs placed by the player
	for b in active_placed_bombs:
		var b_world = grid_to_world(b.pos)
		var pulse = (sin(Time.get_ticks_msec() * 0.015) + 1.0) * 0.5
		var col = Color.RED.lerp(Color(0.2, 0.0, 0.0), pulse)
		draw_circle(b_world, CELL_SIZE/2.0 - 1, col)
		draw_circle(b_world, CELL_SIZE/3.0, Color(0.1, 0.1, 0.1))
		var sec_left = str(int(ceil(b.timer)))
		draw_string(ThemeDB.fallback_font, b_world + Vector2(-3, 4), sec_left, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color.YELLOW)
	
	# Death tint over the level (drawn after the level so it is not covered)
	if is_player_dead:
		draw_rect(Rect2(0, 0, grid_width * CELL_SIZE, grid_height * CELL_SIZE), Color(0.3, 0, 0, 0.3))

	# DEBUG / HUD: Show coordinates and progress
	var win_text = ""
	match current_win_condition:
		WinCondition.ALL_COINS:
			win_text = "Monedas: %d/%d" % [coins_collected, total_coins]
		WinCondition.TARGET_AMOUNT:
			win_text = "Monedas: %d/%d" % [coins_collected, target_coin_amount]
		WinCondition.SPECIFIC_ITEM:
			win_text = "Ítem Misión: %s" % ("SÍ" if mission_item_collected else "NO")
		WinCondition.EXIT_ONLY:
			win_text = "Llega a la salida"
	
	if _is_win_condition_met() and require_exit:
		win_text += " [¡SALIDA ABIERTA!]"
	
	var hud_text = "Bombas: %d | " % player_bombs_ammo + win_text
	var debug_text = "Player: (" + str(player_grid_pos.x) + "," + str(player_grid_pos.y) + ") | " + hud_text
	if hud_label:
		hud_label.text = debug_text
	
	# DEBUG: Logic border for the player (grid)
	if config.get("show_player_logic", false):
		var player_logic_pos = grid_to_world(player_grid_pos) - Vector2(CELL_SIZE/2.0, CELL_SIZE/2.0)
		draw_rect(Rect2(player_logic_pos, Vector2(CELL_SIZE, CELL_SIZE)), Color.RED, false, 1)

	# DEBUG: Logic border for rocks (scanning the actual grid)
	if config.get("show_rock_logic", false):
		for y in range(grid_height):
			for x in range(grid_width):
				if grid[y][x] == TileType.PIEDRA:
					var rock_logic_pos = grid_to_world(Vector2i(x, y)) - Vector2(CELL_SIZE/2.0, CELL_SIZE/2.0)
					draw_rect(Rect2(rock_logic_pos, Vector2(CELL_SIZE, CELL_SIZE)), Color.BLUE, false, 1)

func _get_tile_color(tile: int) -> Color:
	match tile:
		TileType.EMPTY:
			return Color(0.1, 0.1, 0.15)
		TileType.TIERRA:
			return Color(0.4, 0.3, 0.2)
		TileType.PIEDRA, TileType.ITEM_RECOMPENSA, TileType.BOMBA:
			return Color.TRANSPARENT # Drawn separately for rotation and animations
		TileType.MURO_IRROMPIBLE:
			return Color(0.2, 0.2, 0.25)
		TileType.MURO_ROMPIBLE:
			return Color(0.3, 0.25, 0.2)
		TileType.ITEM_MISION:
			return Color(0.2, 0.8, 0.3)
		TileType.SALIDA:
			return Color(0.3, 0.6, 0.9)
		TileType.ITEM_INVENTARIO, TileType.BOMB_PICKUP:
			return Color(0.4, 0.3, 0.2) # Dirt base
		_:
			return Color.WHITE

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		grid_pos.x * CELL_SIZE + CELL_SIZE / 2.0,
		grid_pos.y * CELL_SIZE + CELL_SIZE / 2.0
	)

func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(world_pos.x / CELL_SIZE),
		int(world_pos.y / CELL_SIZE)
	)

func _input(event):
	# Map actions to directions (move_* or ui_* for D-Pad compatibility)
	var dir = Vector2i.ZERO
	if event.is_action("move_up") or event.is_action("ui_up"): dir = Vector2i(0, -1)
	elif event.is_action("move_down") or event.is_action("ui_down"): dir = Vector2i(0, 1)
	elif event.is_action("move_left") or event.is_action("ui_left"): dir = Vector2i(-1, 0)
	elif event.is_action("move_right") or event.is_action("ui_right"): dir = Vector2i(1, 0)
	
	if dir != Vector2i.ZERO:
		if event.is_pressed():
			if not input_stack.has(dir):
				input_stack.append(dir)
		else:
			input_stack.erase(dir)

## Drops held directions whose action is no longer pressed. Releases that happen while the
## tree is paused (pause menu) never reach _input, so the stack is also checked every frame.
func _prune_released_directions() -> void:
	for dir in input_stack.duplicate():
		if not _is_direction_held(dir):
			input_stack.erase(dir)

func _is_direction_held(dir: Vector2i) -> bool:
	if dir == Vector2i(0, -1):
		return Input.is_action_pressed("move_up") or Input.is_action_pressed("ui_up")
	if dir == Vector2i(0, 1):
		return Input.is_action_pressed("move_down") or Input.is_action_pressed("ui_down")
	if dir == Vector2i(-1, 0):
		return Input.is_action_pressed("move_left") or Input.is_action_pressed("ui_left")
	if dir == Vector2i(1, 0):
		return Input.is_action_pressed("move_right") or Input.is_action_pressed("ui_right")
	return false

## Returns whether a grid position is within the level bounds.
func _in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < grid_width and pos.y >= 0 and pos.y < grid_height

## Processes picking up a tile's content (bomb, inventory item, coin or mission item).
## Returns true if the tile was collectible; the caller empties the tile and moves the player.
func _collect_tile(pos: Vector2i, tile: int) -> bool:
	match tile:
		TileType.BOMB_PICKUP:
			player_bombs_ammo += 1
			AudioManager.play_sfx(&"sfx_exc_bomb_pickup")
		TileType.ITEM_INVENTARIO:
			var item_id: String = Inventory.GOLD_ITEM_ID
			var item_amount: int = 1
			if cell_items.has(pos):
				# Hand-placed item with a specific reward
				item_id = str(cell_items[pos].get("id", item_id))
				item_amount = int(cell_items[pos].get("amount", 1))
				cell_items.erase(pos)
			elif item_pool.size() > 0:
				item_id = str(item_pool[randi() % item_pool.size()])
			AudioManager.play_sfx(&"sfx_exc_item")
			add_reward(item_id, item_amount)
		TileType.ITEM_RECOMPENSA:
			AudioManager.play_sfx(&"sfx_exc_coin")
			add_reward(Inventory.GOLD_ITEM_ID, 1)
			coins_collected += 1
			var key: String = str(pos.x) + "," + str(pos.y)
			if falling_visuals.has(key):
				falling_visuals.erase(key)
		TileType.ITEM_MISION:
			mission_item_collected = true
			AudioManager.play_sfx(&"sfx_exc_quest_item")
		_:
			return false
	_finish_if_goal_reached()
	return true

## Without require_exit, meeting the goal wins the minigame right away.
func _finish_if_goal_reached() -> void:
	if not require_exit and _is_win_condition_met():
		AudioManager.play_ui(&"sfx_exc_exit_open")
		finish(true)

func _try_move_player(direction: Vector2i) -> void:
	var new_pos: Vector2i = player_grid_pos + direction
	
	if not _in_bounds(new_pos):
		return
	
	var target_tile = grid[new_pos.y][new_pos.x]
	
	# Try to push rock or bomb
	if target_tile == TileType.PIEDRA or target_tile == TileType.BOMBA:
		if _try_push_rock(new_pos, direction):
			player_grid_pos = new_pos
			is_pushing_rock = true
			AudioManager.play_sfx(&"sfx_exc_push")
			queue_redraw()
		else:
			is_pushing_rock = false
			AudioManager.play_sfx(&"sfx_exc_push_blocked")
		return
	
	# Normal movement
	is_pushing_rock = false
	
	match target_tile:
		TileType.EMPTY:
			player_grid_pos = new_pos
			if _step_sound_cooldown <= 0.0:
				_step_sound_cooldown = STEP_SOUND_INTERVAL
				AudioManager.play_sfx(&"sfx_exc_step")
			queue_redraw()
		
		TileType.TIERRA:
			AudioManager.play_sfx(&"sfx_exc_dig")
			grid[new_pos.y][new_pos.x] = TileType.EMPTY
			player_grid_pos = new_pos
			queue_redraw()
		
		TileType.BOMB_PICKUP, TileType.ITEM_INVENTARIO, TileType.ITEM_MISION, TileType.ITEM_RECOMPENSA:
			_collect_tile(new_pos, target_tile)
			grid[new_pos.y][new_pos.x] = TileType.EMPTY
			player_grid_pos = new_pos
			queue_redraw()
		
		TileType.SALIDA:
			if _is_win_condition_met():
				player_grid_pos = new_pos
				queue_redraw()
				AudioManager.play_ui(&"sfx_exc_exit_open")
				finish(true)
			else:
				AudioManager.play_sfx(&"sfx_exc_exit_blocked")

func _try_push_rock(rock_pos: Vector2i, direction: Vector2i) -> bool:
	# Can only be pushed horizontally
	if direction.y != 0:
		return false

	var push_dest: Vector2i = rock_pos + direction
	
	# Check bounds
	if not _in_bounds(push_dest):
		return false
	
	# Check that the destination is empty
	if grid[push_dest.y][push_dest.x] != TileType.EMPTY:
		return false
	
	var pushed_tile = grid[rock_pos.y][rock_pos.x]
	# Push the rock or bomb
	grid[push_dest.y][push_dest.x] = pushed_tile
	grid[rock_pos.y][rock_pos.x] = TileType.EMPTY

	# Update visual rotation and state transfer
	var old_key = str(rock_pos.x) + "," + str(rock_pos.y)
	var new_key = str(push_dest.x) + "," + str(push_dest.y)

	# If the visual somehow doesn't exist, initialize it at the old position
	var data = falling_visuals.get(old_key, {
		"visual_pos": grid_to_world(rock_pos),
		"rotation": 0.0,
		"type": pushed_tile
	})
	data.type = pushed_tile
	data.rotation += PI/2 * direction.x # Rotate 90 degrees
	falling_visuals[new_key] = data
	if new_key != old_key:
		falling_visuals.erase(old_key)

	return true

func _try_dig_adjacent(direction: Vector2i) -> void:
	var target_pos: Vector2i = player_grid_pos + direction
	
	if not _in_bounds(target_pos):
		return

	var target_tile = grid[target_pos.y][target_pos.x]

	if target_tile == TileType.TIERRA:
		AudioManager.play_sfx(&"sfx_exc_dig")
		grid[target_pos.y][target_pos.x] = TileType.EMPTY
		queue_redraw()
	elif _collect_tile(target_pos, target_tile):
		grid[target_pos.y][target_pos.x] = TileType.EMPTY
		queue_redraw()

func _is_win_condition_met() -> bool:
	match current_win_condition:
		WinCondition.ALL_COINS:
			return coins_collected >= total_coins
		WinCondition.TARGET_AMOUNT:
			return coins_collected >= target_coin_amount
		WinCondition.SPECIFIC_ITEM:
			return mission_item_collected
		WinCondition.EXIT_ONLY:
			return true
	return false

func _update_gravity():
	if is_player_dead:
		return
		
	var moved = false
	# Use a set to track which coordinates were already processed this tick
	# to prevent a rock from moving twice in one tick (e.g. slide right and then fall)
	var processed_this_tick = {}
	var next_falling_rocks = {}
	
	# Process bottom-up so rocks/objects fall naturally
	var next_pending_falls = {}
	
	for y in range(grid_height - 2, -1, -1):
		for x in range(grid_width):
			var tile = grid[y][x]
			if tile == TileType.PIEDRA or tile == TileType.ITEM_RECOMPENSA or tile == TileType.BOMBA:
				var key = str(x) + "," + str(y)
				if processed_this_tick.has(key):
					continue
				
				var was_falling = falling_objects.has(key)
				
				# DELAY RULE (~0.1s, about 1 tick of 0.12s)
				if not was_falling:
					# Check whether the object COULD fall or slide
					var can_move = _check_if_can_fall_or_slide(x, y, tile)
					if can_move:
						if pending_falls.has(key):
							var ticks = pending_falls[key] - 1
							if ticks <= 0:
								# Waited long enough, proceed to move
								pass 
							else:
								next_pending_falls[key] = ticks
								continue
						else:
							# Start waiting (1 tick of delay)
							next_pending_falls[key] = 1
							continue
				
				var res = _try_fall_rock(x, y, was_falling, tile)
				if was_falling and not res.moved and tile == TileType.PIEDRA:
					AudioManager.play_sfx(&"sfx_exc_rock_land")
				
				if res.moved:
					moved = true
					# Mark the NEW position as processed for this tick
					var new_key = str(res.new_pos.x) + "," + str(res.new_pos.y)
					processed_this_tick[new_key] = true
					
					# If the bomb exploded in res, the tile is already EMPTY
					if grid[res.new_pos.y][res.new_pos.x] != TileType.EMPTY:
						# Transfer or update visuals
						var visual_data = falling_visuals.get(key, {
							"visual_pos": grid_to_world(Vector2i(x,y)),
							"rotation": 0.0,
							"type": tile
						})
						if res.rotated:
							if tile == TileType.PIEDRA:
								AudioManager.play_sfx(&"sfx_exc_rock_slide")
							visual_data.rotation += PI/2
						falling_visuals[new_key] = visual_data
						if new_key != key:
							falling_visuals.erase(key)
						
						# If it moved down, it keeps falling
						if res.new_pos.y > y:
							next_falling_rocks[new_key] = true
	
	falling_objects = next_falling_rocks
	pending_falls = next_pending_falls
	if moved:
		queue_redraw()

func _check_if_can_fall_or_slide(x: int, y: int, _tile_type: int) -> bool:
	# Rule 1: Direct fall
	if y + 1 < grid_height:
		var dest = Vector2i(x, y + 1)
		if grid[dest.y][dest.x] == TileType.EMPTY and player_grid_pos != dest:
			return true
	
	# Rule 2: Side slide (only over other rocks, coins or bombs)
	if y + 1 < grid_height:
		var below = grid[y + 1][x]
		if below == TileType.PIEDRA or below == TileType.ITEM_RECOMPENSA or below == TileType.BOMBA:
			# Try left
			if x > 0:
				var side = Vector2i(x - 1, y)
				var dest = Vector2i(x - 1, y + 1)
				if grid[side.y][side.x] == TileType.EMPTY and player_grid_pos != side:
					if grid[dest.y][dest.x] == TileType.EMPTY and player_grid_pos != dest:
						return true
			# Try right
			if x < grid_width - 1:
				var side = Vector2i(x + 1, y)
				var dest = Vector2i(x + 1, y + 1)
				if grid[side.y][side.x] == TileType.EMPTY and player_grid_pos != side:
					if grid[dest.y][dest.x] == TileType.EMPTY and player_grid_pos != dest:
						return true
	return false

func _try_fall_rock(x: int, y: int, was_falling: bool, tile_type: int) -> Dictionary:
	var result = {"moved": false, "new_pos": Vector2i(x, y), "rotated": false}
	
	# Special case AMBIENT BOMB:
	# If it was falling and the space below is blocked, it hits and explodes in 3x3
	if tile_type == TileType.BOMBA and was_falling:
		var below_blocked = (y + 1 >= grid_height) or (grid[y + 1][x] != TileType.EMPTY)
		if below_blocked:
			grid[y][x] = TileType.EMPTY
			var key = str(x) + "," + str(y)
			if falling_visuals.has(key):
				falling_visuals.erase(key)
			AudioManager.play_sfx(&"sfx_exc_bomb_impact")
			_explode_at(Vector2i(x, y), "BOMBA AMBIENTAL IMPACTO")
			result.moved = true
			return result

	# Rule 1: Direct fall if there is empty space below
	if y + 1 < grid_height and grid[y + 1][x] == TileType.EMPTY:
		var dest = Vector2i(x, y + 1)
		
		# FINE-TUNED RULE: If it was NOT falling and the player is at the destination, 
		# the player holds it (it does not start falling).
		if not was_falling and player_grid_pos == dest:
			return result
		
		# If it WAS already falling and the player is in the way:
		if player_grid_pos == dest:
			if tile_type == TileType.BOMBA:
				grid[y][x] = TileType.EMPTY
				var key = str(x) + "," + str(y)
				if falling_visuals.has(key):
					falling_visuals.erase(key)
				AudioManager.play_sfx(&"sfx_exc_bomb_impact")
				_explode_at(dest, "BOMBA AMBIENTAL IMPACTO DIRECTO")
				result.moved = true
				return result
			else:
				_player_crushed()
		
		if not was_falling and tile_type == TileType.PIEDRA:
			AudioManager.play_sfx(&"sfx_exc_rock_fall")
		grid[dest.y][dest.x] = tile_type
		grid[y][x] = TileType.EMPTY
		result.moved = true
		result.new_pos = dest
		return result
	
	# Rule 2: Side slide (only over other rocks, coins or bombs)
	if y + 1 < grid_height:
		var below = grid[y + 1][x]
		if below == TileType.PIEDRA or below == TileType.ITEM_RECOMPENSA or below == TileType.BOMBA:
			# Try left
			if x > 0:
				var side = Vector2i(x - 1, y)
				var dest = Vector2i(x - 1, y + 1)
				# Check that the side and destination are empty and free of the player
				if grid[side.y][side.x] == TileType.EMPTY and player_grid_pos != side:
					if grid[dest.y][dest.x] == TileType.EMPTY and player_grid_pos != dest:
						grid[dest.y][dest.x] = tile_type
						grid[y][x] = TileType.EMPTY
						result.moved = true
						result.new_pos = dest
						result.rotated = true
						return result
			
			# Try right
			if x < grid_width - 1:
				var side = Vector2i(x + 1, y)
				var dest = Vector2i(x + 1, y + 1)
				if grid[side.y][side.x] == TileType.EMPTY and player_grid_pos != side:
					if grid[dest.y][dest.x] == TileType.EMPTY and player_grid_pos != dest:
						grid[dest.y][dest.x] = tile_type
						grid[y][x] = TileType.EMPTY
						result.moved = true
						result.new_pos = dest
						result.rotated = true
						return result
			
	return result

func _player_crushed() -> void:
	if is_player_dead:
		return
	is_player_dead = true
	AudioManager.play_ui(&"sfx_exc_crushed")

	# Immediate visual feedback
	queue_redraw()
	
	# End immediately (or with a one-frame delay to see the impact)
	await get_tree().process_frame
	AudioManager.play_ui(&"sfx_exc_lose")
	finish(false)
