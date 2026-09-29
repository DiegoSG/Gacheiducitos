extends MinigameBase
class_name MG_ExcavationGame

# Referencia a tipos compartidos
const MGT = preload("res://src/minigames/mg_excavation/mg_excavation_types.gd")
const TileType = MGT.TileType
const WinCondition = MGT.WinCondition

# Configuración del grid
const CELL_SIZE: int = 16
var grid_width: int = 40
var grid_height: int = 23

# Grid de tiles (Array 2D)
var grid: Array = []

# Referencia al jugador
var player_grid_pos: Vector2i = Vector2i(1, 1)
var is_player_dead: bool = false

# Estado de la misión
var total_coins: int = 0
var coins_collected: int = 0
var mission_item_collected: bool = false
var current_win_condition: int = WinCondition.ALL_COINS
var target_coin_amount: int = 0

# Configuración recibida del debug screen
var config: Dictionary = {}

# Sistema de gravedad
var gravity_timer: float = 0.0
const GRAVITY_TICK: float = 0.12 # Mismo delay que el movimiento del jugador

# Sistema de movimiento continuo
var move_timer: float = 0.0
const MOVE_DELAY: float = 0.12
var current_direction: Vector2i = Vector2i.ZERO

# Sistema de empuje de piedras y visuales
var is_pushing_rock: bool = false
const PUSH_DELAY: float = 0.24 # Mitad de velocidad al empujar
var falling_visuals: Dictionary = {} # "x,y" -> { "visual_pos": Vector2, "rotation": float, "type": int }
var falling_objects: Dictionary = {} # "x,y" -> true (coordenadas de las que ya venían cayendo)
var pending_falls: Dictionary = {} # "x,y" -> ticks_remaining (objetos que quieren empezar a caer)

# Sistema de bombas
var player_bombs_ammo: int = 0
var space_held_timer: float = 0.0
const BOMB_PLANT_HOLD_TIME: float = 0.35
var active_placed_bombs: Array = [] # Array[Dictionary]: [{"pos": Vector2i, "timer": 4.0}]
var deliver_items: bool = false
var item_pool: Array = []

# Texturas
var coin_texture: Texture2D = null
var bomb_texture: Texture2D = null
var potion_texture: Texture2D = null
var player_texture: Texture2D = null

# Sistema de interpolación suave
var visual_player_pos: Vector2 = Vector2.ZERO
var interp_speed: float = 15.0

# Gestión de inputs refinada
var input_stack: Array = [] # Lista de direcciones presionadas en orden

# Cámara
var camera: Camera2D = null

func _ready() -> void:
	# Textura de moneda compartida (con fallback) desde MinigameBase
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
	
	# Aplicar escala global
	var s = config.get("escala", 1.5)
	self.scale = Vector2(s, s)
	
	_initialize_grid()
	_generate_level()
	
	# Inicializar estado de misión desde config
	current_win_condition = config.get("win_condition", WinCondition.ALL_COINS)
	target_coin_amount = config.get("target_amount", 5)
	_count_total_coins()
	
	# Inicializar posiciones visuales
	visual_player_pos = grid_to_world(player_grid_pos)
	_initialize_falling_visuals()
	
	# Configurar cámara
	_setup_camera()
	
	queue_redraw()

func _setup_camera() -> void:
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	
	# Configurar límites de la cámara (2 tiles extra de margen)
	# Usamos global_position por si el nodo raíz no está en (0,0)
	var s = self.scale.x
	var margin = 2 * CELL_SIZE
	var origin = self.global_position
	
	camera.limit_left = int(origin.x - (margin * s))
	camera.limit_top = int(origin.y - (margin * s))
	camera.limit_right = int(origin.x + (grid_width * CELL_SIZE + margin) * s)
	camera.limit_bottom = int(origin.y + (grid_height * CELL_SIZE + margin) * s)
	
	# Suavizado de la cámara para que no dé tirones con la interpolación
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 10.0
	
	_update_camera_position()

func _update_camera_position() -> void:
	if camera:
		# La posición de la cámara debe ser relativa al mundo global
		# visual_player_pos está en coordenadas locales del grid
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
		_interpolate_visuals(delta) # Seguir interpolando aunque muera para ver el impacto
		queue_redraw()
		return

	# Procesar cuenta regresiva de bombas colocadas por el jugador
	_update_placed_bombs(delta)

	# Procesar plantado de bomba con espacio sostenido
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
	if Input.is_action_pressed("ui_accept"):
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
	
	# Verificar si ya hay una bomba en la posición del jugador
	for b in active_placed_bombs:
		if b.pos == player_grid_pos:
			return
			
	player_bombs_ammo -= 1
	active_placed_bombs.append({
		"pos": player_grid_pos,
		"timer": 4.0
	})
	queue_redraw()

func _update_placed_bombs(delta: float) -> void:
	var remaining: Array = []
	for b in active_placed_bombs:
		b.timer -= delta
		if b.timer <= 0.0:
			_explode_at(b.pos, "BOMBA MANUAL")
		else:
			remaining.append(b)
	active_placed_bombs = remaining

func _explode_at(center_pos: Vector2i, reason: String = "EXPLOSIÓN") -> void:
	# Destruir área de 3x3
	var player_caught = false
	var chain_explosions: Array[Vector2i] = []
	
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var tx = center_pos.x + dx
			var ty = center_pos.y + dy
			if _in_bounds(Vector2i(tx, ty)):
				var t = grid[ty][tx]
				# Encadenar si hay otra bomba ambiental
				if (dx != 0 or dy != 0) and t == TileType.BOMBA:
					chain_explosions.append(Vector2i(tx, ty))
					
				# La salida y los bordes indestructibles son inmunes
				if t != TileType.SALIDA and t != TileType.MURO_IRROMPIBLE:
					grid[ty][tx] = TileType.EMPTY
					var key = str(tx) + "," + str(ty)
					if falling_visuals.has(key):
						falling_visuals.erase(key)
				if player_grid_pos == Vector2i(tx, ty):
					player_caught = true
					
	# Eliminar bombas manuales atrapadas en el radio de la explosión
	var remaining_bombs: Array = []
	for b in active_placed_bombs:
		if abs(b.pos.x - center_pos.x) <= 1 and abs(b.pos.y - center_pos.y) <= 1:
			pass
		else:
			remaining_bombs.append(b)
	active_placed_bombs = remaining_bombs
	
	queue_redraw()
	
	# Ejecutar explosiones en cadena
	for next_bomb in chain_explosions:
		_explode_at(next_bomb, "EXPLOSIÓN EN CADENA")
	
	if player_caught:
		_player_crushed(reason)

func _interpolate_visuals(delta: float) -> void:
	# Interpolar jugador
	var target_player_world = grid_to_world(player_grid_pos)
	visual_player_pos = visual_player_pos.lerp(target_player_world, interp_speed * delta)
	
	# Interpolar piedras y objetos
	for key in falling_visuals:
		var data = falling_visuals[key]
		var coords = key.split(",")
		var target_world = grid_to_world(Vector2i(int(coords[0]), int(coords[1])))
		data.visual_pos = data.visual_pos.lerp(target_world, interp_speed * delta)

func _handle_continuous_movement(delta: float) -> void:
	var direction: Vector2i = Vector2i.ZERO
	
	if input_stack.size() > 0:
		direction = input_stack[-1] # Usar la última tecla presionada
	
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
	if Input.is_action_pressed("ui_accept"):
		_try_dig_adjacent(direction)
	else:
		_try_move_player(direction)

func _initialize_grid() -> void:
	grid.clear()
	for y in range(grid_height):
		var row: Array = []
		for x in range(grid_width):
			row.append(TileType.EMPTY)
		grid.append(row)

func _generate_level() -> void:
	var LevelGen = load("res://src/minigames/mg_excavation/level_generator.gd")
	grid = LevelGen.generate_level(grid_width, grid_height, config)

func _count_total_coins() -> void:
	total_coins = 0
	for y in range(grid_height):
		for x in range(grid_width):
			if grid[y][x] == TileType.ITEM_RECOMPENSA:
				total_coins += 1
	if current_win_condition == WinCondition.ALL_COINS:
		target_coin_amount = total_coins

func _draw():
	if is_player_dead:
		draw_rect(Rect2(0, 0, grid_width * CELL_SIZE, grid_height * CELL_SIZE), Color(0.3, 0, 0, 0.3))

	# 1. Fondo base uniforme para todo el nivel (evita "huecos" bajo las piedras)
	var total_size = Vector2(grid_width * CELL_SIZE, grid_height * CELL_SIZE)
	draw_rect(Rect2(Vector2.ZERO, total_size), Color(0.1, 0.1, 0.15))

	for y in range(grid_height):
		for x in range(grid_width):
			var tile = grid[y][x]
			var pos = Vector2(x * CELL_SIZE, y * CELL_SIZE)
			
			# Dibujar cuadrícula sutil
			draw_rect(Rect2(pos, Vector2(CELL_SIZE, CELL_SIZE)), Color(0, 0, 0, 0.1), false, 1)
			
			var color = _get_tile_color(tile)
			# Solo dibujar el contenido si no es vacío y no es transparente (piedras/jugador se dibujan después)
			if color != Color.TRANSPARENT and tile != TileType.EMPTY:
				draw_rect(Rect2(pos, Vector2(CELL_SIZE, CELL_SIZE)), color)
				draw_rect(Rect2(pos, Vector2(CELL_SIZE, CELL_SIZE)), Color(0, 0, 0, 0.2), false, 1)
				
				# Detalles para pickups que sustituyen tierra
				if tile == TileType.BOMB_PICKUP:
					draw_circle(pos + Vector2(CELL_SIZE/2.0, CELL_SIZE/2.0), CELL_SIZE/3.5, Color(0.05, 0.05, 0.05))
					draw_circle(pos + Vector2(CELL_SIZE/2.0 + 2, CELL_SIZE/2.0 - 2), 2, Color.RED)
				elif tile == TileType.ITEM_INVENTARIO:
					if potion_texture:
						draw_texture_rect(potion_texture, Rect2(pos + Vector2(2, 2), Vector2(CELL_SIZE - 4, CELL_SIZE - 4)), false)
					else:
						draw_circle(pos + Vector2(CELL_SIZE/2.0, CELL_SIZE/2.0), CELL_SIZE/3.0, Color(0.9, 0.4, 0.9))
	
	# Dibujar jugador usando posición visual
	if player_texture:
		var draw_p = visual_player_pos - Vector2(CELL_SIZE/2.0, CELL_SIZE/2.0)
		draw_texture_rect(player_texture, Rect2(draw_p, Vector2(CELL_SIZE, CELL_SIZE)), false)
	else:
		draw_rect(Rect2(visual_player_pos - Vector2(CELL_SIZE/2.0, CELL_SIZE/2.0), Vector2(CELL_SIZE, CELL_SIZE)), Color.YELLOW)
		draw_circle(visual_player_pos, CELL_SIZE/3.0, Color.ORANGE)
	
	# Indicador de plantado de bomba (espacio sostenido)
	if space_held_timer > 0.0 and player_bombs_ammo > 0:
		var progress = clamp(space_held_timer / BOMB_PLANT_HOLD_TIME, 0.0, 1.0)
		draw_arc(visual_player_pos, CELL_SIZE * 0.75, 0.0, TAU * progress, 16, Color(1.0, 0.2, 0.2, 0.9), 2.5)
	
	# Dibujar piedras y objetos usando posición visual y rotación
	for key in falling_visuals:
		var data = falling_visuals[key]
		var pos = data.visual_pos
		var rot = data.rotation
		
		draw_set_transform(pos, rot, Vector2.ONE)
		if data.type == TileType.PIEDRA:
			draw_rect(Rect2(-CELL_SIZE/2.0 + 1, -CELL_SIZE/2.0 + 1, CELL_SIZE - 2, CELL_SIZE - 2), Color(0.5, 0.5, 0.5))
			# Detalle para ver la rotación
			draw_rect(Rect2(-CELL_SIZE/2.0 + 3, -CELL_SIZE/2.0 + 3, 4, 4), Color(0.7, 0.7, 0.7)) 
		elif data.type == TileType.BOMBA:
			# Bomba ambiental (círculo oscuro con mecha)
			draw_circle(Vector2.ZERO, CELL_SIZE/2.0 - 2, Color(0.1, 0.1, 0.1))
			draw_circle(Vector2.ZERO, CELL_SIZE/4.0, Color(0.25, 0.25, 0.25))
			draw_circle(Vector2(0, -CELL_SIZE/3.0), 2.5, Color(1.0, 0.3, 0.1))
		elif data.type == TileType.ITEM_RECOMPENSA:
			draw_texture_rect(coin_texture, Rect2(-CELL_SIZE/2.0, -CELL_SIZE/2.0, CELL_SIZE, CELL_SIZE), false)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	
	# Dibujar bombas manuales colocadas por el jugador
	for b in active_placed_bombs:
		var b_world = grid_to_world(b.pos)
		var pulse = (sin(Time.get_ticks_msec() * 0.015) + 1.0) * 0.5
		var col = Color.RED.lerp(Color(0.2, 0.0, 0.0), pulse)
		draw_circle(b_world, CELL_SIZE/2.0 - 1, col)
		draw_circle(b_world, CELL_SIZE/3.0, Color(0.1, 0.1, 0.1))
		var sec_left = str(int(ceil(b.timer)))
		draw_string(ThemeDB.fallback_font, b_world + Vector2(-3, 4), sec_left, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color.YELLOW)
	
	# DEBUG / HUD: Mostrar coordenadas y progreso
	var win_text = ""
	match current_win_condition:
		WinCondition.ALL_COINS:
			win_text = "Monedas: %d/%d" % [coins_collected, total_coins]
		WinCondition.TARGET_AMOUNT:
			win_text = "Monedas: %d/%d" % [coins_collected, target_coin_amount]
		WinCondition.SPECIFIC_ITEM:
			win_text = "Ítem Misión: %s" % ("SÍ" if mission_item_collected else "NO")
	
	if _is_win_condition_met():
		win_text += " [¡SALIDA ABIERTA!]"
	
	var hud_text = "Bombas: %d | " % player_bombs_ammo + win_text
	var debug_text = "Player: (" + str(player_grid_pos.x) + "," + str(player_grid_pos.y) + ") | " + hud_text
	draw_string(ThemeDB.fallback_font, Vector2(10, 20), debug_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	
	# DEBUG: Borde de lógica para el jugador (grid)
	if config.get("show_player_logic", false):
		var player_logic_pos = grid_to_world(player_grid_pos) - Vector2(CELL_SIZE/2.0, CELL_SIZE/2.0)
		draw_rect(Rect2(player_logic_pos, Vector2(CELL_SIZE, CELL_SIZE)), Color.RED, false, 1)

	# DEBUG: Borde de lógica para piedras (escaneando el grid real)
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
			return Color.TRANSPARENT # Se dibuja por separado para rotación y animaciones
		TileType.MURO_IRROMPIBLE:
			return Color(0.2, 0.2, 0.25)
		TileType.MURO_ROMPIBLE:
			return Color(0.3, 0.25, 0.2)
		TileType.ITEM_MISION:
			return Color(0.2, 0.8, 0.3)
		TileType.SALIDA:
			return Color(0.3, 0.6, 0.9)
		TileType.ITEM_INVENTARIO, TileType.BOMB_PICKUP:
			return Color(0.4, 0.3, 0.2) # Base de tierra
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
	if event.is_action_pressed("ui_cancel"):
		finish(false)
		return

	# Mapear acciones a direcciones
	var dir = Vector2i.ZERO
	if event.is_action("ui_up"): dir = Vector2i(0, -1)
	elif event.is_action("ui_down"): dir = Vector2i(0, 1)
	elif event.is_action("ui_left"): dir = Vector2i(-1, 0)
	elif event.is_action("ui_right"): dir = Vector2i(1, 0)
	
	if dir != Vector2i.ZERO:
		if event.is_pressed():
			if not input_stack.has(dir):
				input_stack.append(dir)
		else:
			input_stack.erase(dir)

## Indica si una posición de grid está dentro de los límites del nivel.
func _in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < grid_width and pos.y >= 0 and pos.y < grid_height

## Procesa la recogida del contenido de un tile (bomba, ítem de inventario, moneda o ítem de misión).
## Devuelve true si el tile era recogible; el llamador vacía el tile y mueve al jugador.
## from_dig indica que se recogió al excavar (solo afecta al texto del log).
func _collect_tile(pos: Vector2i, tile: int, from_dig: bool = false) -> bool:
	var suffix: String = " al excavar" if from_dig else ""
	match tile:
		TileType.BOMB_PICKUP:
			player_bombs_ammo += 1
		TileType.ITEM_INVENTARIO:
			var item_id: String = Inventory.GOLD_ITEM_ID
			if item_pool.size() > 0:
				item_id = str(item_pool[randi() % item_pool.size()])
			add_reward(item_id, 1)
		TileType.ITEM_RECOMPENSA:
			add_reward(Inventory.GOLD_ITEM_ID, 1)
			coins_collected += 1
			var key: String = str(pos.x) + "," + str(pos.y)
			if falling_visuals.has(key):
				falling_visuals.erase(key)
		TileType.ITEM_MISION:
			mission_item_collected = true
		_:
			return false
	return true

func _try_move_player(direction: Vector2i) -> void:
	var new_pos: Vector2i = player_grid_pos + direction
	
	if not _in_bounds(new_pos):
		return
	
	var target_tile = grid[new_pos.y][new_pos.x]
	
	# Intentar empujar piedra o bomba
	if target_tile == TileType.PIEDRA or target_tile == TileType.BOMBA:
		if _try_push_rock(new_pos, direction):
			player_grid_pos = new_pos
			is_pushing_rock = true
			queue_redraw()
		else:
			is_pushing_rock = false
		return
	
	# Movimiento normal
	is_pushing_rock = false
	
	match target_tile:
		TileType.EMPTY:
			player_grid_pos = new_pos
			queue_redraw()
		
		TileType.TIERRA:
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
				finish(true)

func _try_push_rock(rock_pos: Vector2i, direction: Vector2i) -> bool:
	# Solo se pueden empujar horizontalmente
	if direction.y != 0:
		return false

	var push_dest: Vector2i = rock_pos + direction
	
	# Verificar límites
	if not _in_bounds(push_dest):
		return false
	
	# Verificar que el destino esté vacío
	if grid[push_dest.y][push_dest.x] != TileType.EMPTY:
		return false
	
	var pushed_tile = grid[rock_pos.y][rock_pos.x]
	# Empujar la piedra o bomba
	grid[push_dest.y][push_dest.x] = pushed_tile
	grid[rock_pos.y][rock_pos.x] = TileType.EMPTY

	# Actualizar rotación visual y transferencia de estado
	var old_key = str(rock_pos.x) + "," + str(rock_pos.y)
	var new_key = str(push_dest.x) + "," + str(push_dest.y)

	# Si por alguna razón no existe el visual, lo inicializamos en la posición vieja
	var data = falling_visuals.get(old_key, {
		"visual_pos": grid_to_world(rock_pos),
		"rotation": 0.0,
		"type": pushed_tile
	})
	data.type = pushed_tile
	data.rotation += PI/2 * direction.x # Girar 90 grados
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
		grid[target_pos.y][target_pos.x] = TileType.EMPTY
		queue_redraw()
	elif _collect_tile(target_pos, target_tile, true):
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
	return false

func _update_gravity():
	if is_player_dead:
		return
		
	var moved = false
	# Usamos un conjunto para rastrear qué coordenadas ya hemos procesado esta vez
	# para evitar que una piedra se mueva dos veces en un solo tick (ej: deslizar derecha y luego caer)
	var processed_this_tick = {}
	var next_falling_rocks = {}
	
	# Procesar de abajo hacia arriba para que las piedras/objetos caigan naturalmente
	var next_pending_falls = {}
	
	for y in range(grid_height - 2, -1, -1):
		for x in range(grid_width):
			var tile = grid[y][x]
			if tile == TileType.PIEDRA or tile == TileType.ITEM_RECOMPENSA or tile == TileType.BOMBA:
				var key = str(x) + "," + str(y)
				if processed_this_tick.has(key):
					continue
				
				var was_falling = falling_objects.has(key)
				
				# REGLA DE RETARDO (0.1s aprox 1 tick de 0.12s)
				if not was_falling:
					# Verificar si el objeto PODRÍA caer o deslizarse
					var can_move = _check_if_can_fall_or_slide(x, y, tile)
					if can_move:
						if pending_falls.has(key):
							var ticks = pending_falls[key] - 1
							if ticks <= 0:
								# Ya esperó suficiente, proceder a mover
								pass 
							else:
								next_pending_falls[key] = ticks
								continue
						else:
							# Empezar espera (1 tick de retraso)
							next_pending_falls[key] = 1
							continue
				
				var res = _try_fall_rock(x, y, was_falling, tile)
				
				if res.moved:
					moved = true
					# Marcar la NUEVA posición como procesada para este tick
					var new_key = str(res.new_pos.x) + "," + str(res.new_pos.y)
					processed_this_tick[new_key] = true
					
					# Si la bomba explotó en res, el tile ya es EMPTY
					if grid[res.new_pos.y][res.new_pos.x] != TileType.EMPTY:
						# Transferir o actualizar visuales
						var visual_data = falling_visuals.get(key, {
							"visual_pos": grid_to_world(Vector2i(x,y)),
							"rotation": 0.0,
							"type": tile
						})
						if res.rotated:
							visual_data.rotation += PI/2
						falling_visuals[new_key] = visual_data
						if new_key != key:
							falling_visuals.erase(key)
						
						# Si se movió hacia abajo, sigue cayendo
						if res.new_pos.y > y:
							next_falling_rocks[new_key] = true
	
	falling_objects = next_falling_rocks
	pending_falls = next_pending_falls
	if moved:
		queue_redraw()

func _check_if_can_fall_or_slide(x: int, y: int, _tile_type: int) -> bool:
	# Regla 1: Caída directa
	if y + 1 < grid_height:
		var dest = Vector2i(x, y + 1)
		if grid[dest.y][dest.x] == TileType.EMPTY and player_grid_pos != dest:
			return true
	
	# Regla 2: Deslizamiento lateral (solo sobre otras piedras, monedas o bombas)
	if y + 1 < grid_height:
		var below = grid[y + 1][x]
		if below == TileType.PIEDRA or below == TileType.ITEM_RECOMPENSA or below == TileType.BOMBA:
			# Probar izquierda
			if x > 0:
				var side = Vector2i(x - 1, y)
				var dest = Vector2i(x - 1, y + 1)
				if grid[side.y][side.x] == TileType.EMPTY and player_grid_pos != side:
					if grid[dest.y][dest.x] == TileType.EMPTY and player_grid_pos != dest:
						return true
			# Probar derecha
			if x < grid_width - 1:
				var side = Vector2i(x + 1, y)
				var dest = Vector2i(x + 1, y + 1)
				if grid[side.y][side.x] == TileType.EMPTY and player_grid_pos != side:
					if grid[dest.y][dest.x] == TileType.EMPTY and player_grid_pos != dest:
						return true
	return false

func _try_fall_rock(x: int, y: int, was_falling: bool, tile_type: int) -> Dictionary:
	var result = {"moved": false, "new_pos": Vector2i(x, y), "rotated": false}
	
	# Caso especial BOMBA AMBIENTAL:
	# Si venía cayendo y el espacio de abajo está bloqueado, golpea y explota en 3x3
	if tile_type == TileType.BOMBA and was_falling:
		var below_blocked = (y + 1 >= grid_height) or (grid[y + 1][x] != TileType.EMPTY)
		if below_blocked:
			grid[y][x] = TileType.EMPTY
			var key = str(x) + "," + str(y)
			if falling_visuals.has(key):
				falling_visuals.erase(key)
			_explode_at(Vector2i(x, y), "BOMBA AMBIENTAL IMPACTO")
			result.moved = true
			return result

	# Regla 1: Caída directa si hay espacio vacío debajo
	if y + 1 < grid_height and grid[y + 1][x] == TileType.EMPTY:
		var dest = Vector2i(x, y + 1)
		
		# REGLA AFINADA: Si NO estaba cayendo, y el jugador está en el destino, 
		# el jugador la sostiene (no empieza a caer).
		if not was_falling and player_grid_pos == dest:
			return result
		
		# Si YA estaba cayendo y el jugador está en el camino:
		if player_grid_pos == dest:
			if tile_type == TileType.BOMBA:
				grid[y][x] = TileType.EMPTY
				var key = str(x) + "," + str(y)
				if falling_visuals.has(key):
					falling_visuals.erase(key)
				_explode_at(dest, "BOMBA AMBIENTAL IMPACTO DIRECTO")
				result.moved = true
				return result
			else:
				_player_crushed("CAÍDA DIRECTA")
		
		grid[dest.y][dest.x] = tile_type
		grid[y][x] = TileType.EMPTY
		result.moved = true
		result.new_pos = dest
		return result
	
	# Regla 2: Deslizamiento lateral (solo sobre otras piedras, monedas o bombas)
	if y + 1 < grid_height:
		var below = grid[y + 1][x]
		if below == TileType.PIEDRA or below == TileType.ITEM_RECOMPENSA or below == TileType.BOMBA:
			# Intentar izquierda
			if x > 0:
				var side = Vector2i(x - 1, y)
				var dest = Vector2i(x - 1, y + 1)
				# Verificar que lateral y destino estén vacíos y sin jugador
				if grid[side.y][side.x] == TileType.EMPTY and player_grid_pos != side:
					if grid[dest.y][dest.x] == TileType.EMPTY and player_grid_pos != dest:
						grid[dest.y][dest.x] = tile_type
						grid[y][x] = TileType.EMPTY
						result.moved = true
						result.new_pos = dest
						result.rotated = true
						return result
			
			# Intentar derecha
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

func _player_crushed(reason: String = "") -> void:
	if is_player_dead:
		return
	is_player_dead = true

	# Feedback visual inmediato
	queue_redraw()
	
	# Terminar inmediatamente (o con un frame de delay para ver el impacto)
	await get_tree().process_frame
	finish(false)
