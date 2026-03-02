extends Node2D
class_name MG_ExcavationGame

# Enumeración de tipos de tiles
enum TileType {
	EMPTY,
	TIERRA,
	PIEDRA,
	MURO_IRROMPIBLE,
	MURO_ROMPIBLE,
	ITEM_MISION,
	ITEM_RECOMPENSA,
	BOMBA,
	ENEMIGO,
	SALIDA,
	TRAMPA_BLOQUEO
}

# Configuración del grid
const CELL_SIZE = 16
var grid_width = 40
var grid_height = 23

# Grid de tiles (Array 2D)
var grid = []

# Referencia al jugador
var player_grid_pos = Vector2i(1, 1)

# Configuración recibida del debug screen
var config = {}

# Sistema de gravedad
var gravity_timer = 0.0
const GRAVITY_TICK = 0.12 # Mismo delay que el movimiento del jugador

# Sistema de movimiento continuo
var move_timer = 0.0
const MOVE_DELAY = 0.12
var current_direction = Vector2i.ZERO

# Sistema de empuje de piedras y visuales
var is_pushing_rock = false
const PUSH_DELAY = 0.24 # Mitad de velocidad al empujar
var rock_visuals = {} # "x,y" -> { "visual_pos": Vector2, "rotation": float }
var falling_rocks = {} # "x,y" -> true (coordenadas de las que ya venían cayendo)

# Sistema de interpolación suave
var visual_player_pos : Vector2
var interp_speed = 15.0

# Gestión de inputs refinada
var input_stack = [] # Lista de direcciones presionadas en orden

# Cámara
var camera : Camera2D

func _ready():
	config = GameManager.minigame_config
	print("MG_Excavation Engine iniciado con config:", config)
	
	# Aplicar escala global
	var s = config.get("escala", 1.5)
	self.scale = Vector2(s, s)
	
	_initialize_grid()
	_generate_level()
	
	# Inicializar posiciones visuales
	visual_player_pos = grid_to_world(player_grid_pos)
	_initialize_rock_visuals()
	
	# Configurar cámara
	_setup_camera()
	
	queue_redraw()

func _setup_camera():
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

func _update_camera_position():
	if camera:
		# La posición de la cámara debe ser relativa al mundo global
		# visual_player_pos está en coordenadas locales del grid
		camera.global_position = self.global_position + (visual_player_pos * self.scale)

func _initialize_rock_visuals():
	rock_visuals.clear()
	for y in range(grid_height):
		for x in range(grid_width):
			if grid[y][x] == TileType.PIEDRA:
				var key = str(x) + "," + str(y)
				rock_visuals[key] = {
					"visual_pos": grid_to_world(Vector2i(x,y)),
					"rotation": 0.0
				}

func _process(delta):
	if is_player_dead:
		_interpolate_visuals(delta) # Seguir interpolando aunque muera para ver el impacto
		queue_redraw()
		return
		
	gravity_timer += delta
	if gravity_timer >= GRAVITY_TICK:
		gravity_timer = 0.0
		_update_gravity()
	
	if not is_player_dead:
		_handle_continuous_movement(delta)
	
	_interpolate_visuals(delta)
	_update_camera_position()
	queue_redraw()

func _interpolate_visuals(delta):
	# Interpolar jugador
	var target_player_world = grid_to_world(player_grid_pos)
	visual_player_pos = visual_player_pos.lerp(target_player_world, interp_speed * delta)
	
	# Interpolar piedras
	for key in rock_visuals:
		var data = rock_visuals[key]
		var coords = key.split(",")
		var target_rock_world = grid_to_world(Vector2i(int(coords[0]), int(coords[1])))
		data.visual_pos = data.visual_pos.lerp(target_rock_world, interp_speed * delta)

func _handle_continuous_movement(delta):
	var direction = Vector2i.ZERO
	
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

func _handle_player_action(direction: Vector2i):
	if Input.is_action_pressed("ui_accept"):
		_try_dig_adjacent(direction)
	else:
		_try_move_player(direction)

func _initialize_grid():
	grid.clear()
	for y in range(grid_height):
		var row = []
		for x in range(grid_width):
			row.append(TileType.EMPTY)
		grid.append(row)

func _generate_level():
	var LevelGen = load("res://scenes/minigames/mg_excavation/level_generator.gd")
	grid = LevelGen.generate_level(grid_width, grid_height, config)
	print("Nivel generado proceduralmente")

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
	
	# Dibujar jugador usando posición visual
	draw_rect(Rect2(visual_player_pos - Vector2(CELL_SIZE/2, CELL_SIZE/2), Vector2(CELL_SIZE, CELL_SIZE)), Color.YELLOW)
	draw_circle(visual_player_pos, CELL_SIZE/3, Color.ORANGE)
	
	# Dibujar piedras usando posición visual y rotación
	for key in rock_visuals:
		var data = rock_visuals[key]
		var pos = data.visual_pos
		var rot = data.rotation
		
		draw_set_transform(pos, rot, Vector2.ONE)
		draw_rect(Rect2(-CELL_SIZE/2 + 1, -CELL_SIZE/2 + 1, CELL_SIZE - 2, CELL_SIZE - 2), Color(0.5, 0.5, 0.5))
		# Detalle para ver la rotación
		draw_rect(Rect2(-CELL_SIZE/2 + 3, -CELL_SIZE/2 + 3, 4, 4), Color(0.7, 0.7, 0.7)) 
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	
	# DEBUG: Mostrar coordenadas
	var debug_text = "Player Grid: (" + str(player_grid_pos.x) + "," + str(player_grid_pos.y) + ")"
	draw_string(ThemeDB.fallback_font, Vector2(10, 20), debug_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	
	# DEBUG: Borde de lógica para el jugador (grid)
	if config.get("show_player_logic", false):
		var player_logic_pos = grid_to_world(player_grid_pos) - Vector2(CELL_SIZE/2, CELL_SIZE/2)
		draw_rect(Rect2(player_logic_pos, Vector2(CELL_SIZE, CELL_SIZE)), Color.RED, false, 1)

	# DEBUG: Borde de lógica para piedras (escaneando el grid real)
	if config.get("show_rock_logic", false):
		for y in range(grid_height):
			for x in range(grid_width):
				if grid[y][x] == TileType.PIEDRA:
					var rock_logic_pos = grid_to_world(Vector2i(x, y)) - Vector2(CELL_SIZE/2, CELL_SIZE/2)
					draw_rect(Rect2(rock_logic_pos, Vector2(CELL_SIZE, CELL_SIZE)), Color.BLUE, false, 1)

func _get_tile_color(tile: TileType) -> Color:
	match tile:
		TileType.EMPTY:
			return Color(0.1, 0.1, 0.15)
		TileType.TIERRA:
			return Color(0.4, 0.3, 0.2)
		TileType.PIEDRA:
			return Color.TRANSPARENT # Se dibuja por separado para rotación
		TileType.MURO_IRROMPIBLE:
			return Color(0.2, 0.2, 0.25)
		TileType.MURO_ROMPIBLE:
			return Color(0.3, 0.25, 0.2)
		TileType.ITEM_MISION:
			return Color(0.2, 0.8, 0.3)
		TileType.ITEM_RECOMPENSA:
			return Color(0.9, 0.8, 0.2)
		TileType.SALIDA:
			return Color(0.3, 0.6, 0.9)
		_:
			return Color.WHITE

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		grid_pos.x * CELL_SIZE + CELL_SIZE / 2,
		grid_pos.y * CELL_SIZE + CELL_SIZE / 2
	)

func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(world_pos.x / CELL_SIZE),
		int(world_pos.y / CELL_SIZE)
	)

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		GameManager.return_to_overworld()
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

func _try_move_player(direction: Vector2i):
	var new_pos = player_grid_pos + direction
	
	if new_pos.x < 0 or new_pos.x >= grid_width or new_pos.y < 0 or new_pos.y >= grid_height:
		return
	
	var target_tile = grid[new_pos.y][new_pos.x]
	
	# Intentar empujar piedra
	if target_tile == TileType.PIEDRA:
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
		
		TileType.ITEM_MISION, TileType.ITEM_RECOMPENSA:
			grid[new_pos.y][new_pos.x] = TileType.EMPTY
			player_grid_pos = new_pos
			queue_redraw()
		
		TileType.SALIDA:
			player_grid_pos = new_pos
			queue_redraw()
			print("¡Nivel completado!")
			await get_tree().create_timer(1.0).timeout
			GameManager.return_to_overworld()

func _try_push_rock(rock_pos: Vector2i, direction: Vector2i) -> bool:
	# Solo se pueden empujar horizontalmente
	if direction.y != 0:
		return false
	
	var push_dest = rock_pos + direction
	
	# Verificar límites
	if push_dest.x < 0 or push_dest.x >= grid_width or push_dest.y < 0 or push_dest.y >= grid_height:
		return false
	
	# Verificar que el destino esté vacío
	if grid[push_dest.y][push_dest.x] != TileType.EMPTY:
		return false
	
	# Empujar la piedra
	grid[push_dest.y][push_dest.x] = TileType.PIEDRA
	grid[rock_pos.y][rock_pos.x] = TileType.EMPTY
	
	# Actualizar rotación visual y transferencia de estado
	var old_key = str(rock_pos.x) + "," + str(rock_pos.y)
	var new_key = str(push_dest.x) + "," + str(push_dest.y)
	
	# Si por alguna razón no existe el visual, lo inicializamos en la posición vieja
	var data = rock_visuals.get(old_key, {
		"visual_pos": grid_to_world(rock_pos),
		"rotation": 0.0
	})
	
	data.rotation += PI/2 * direction.x # Girar 90 grados
	rock_visuals[new_key] = data
	if new_key != old_key:
		rock_visuals.erase(old_key)
	
	print("Empujando piedra")
	return true

func _try_dig_adjacent(direction: Vector2i):
	var target_pos = player_grid_pos + direction
	
	if target_pos.x < 0 or target_pos.x >= grid_width or target_pos.y < 0 or target_pos.y >= grid_height:
		return
	
	var target_tile = grid[target_pos.y][target_pos.x]
	
	if target_tile == TileType.TIERRA:
		grid[target_pos.y][target_pos.x] = TileType.EMPTY
		queue_redraw()

# Estado del juego
var is_player_dead = false

func _update_gravity():
	if is_player_dead:
		return
		
	var moved = false
	# Usamos un conjunto para rastrear qué coordenadas ya hemos procesado esta vez
	# para evitar que una piedra se mueva dos veces en un solo tick (ej: deslizar derecha y luego caer)
	var processed_this_tick = {}
	var next_falling_rocks = {}
	
	# Procesamos de abajo hacia arriba para que las piedras caigan naturalmente
	for y in range(grid_height - 2, -1, -1):
		for x in range(grid_width):
			if grid[y][x] == TileType.PIEDRA:
				var key = str(x) + "," + str(y)
				if processed_this_tick.has(key):
					continue
					
				var was_falling = falling_rocks.has(key)
				var res = _try_fall_rock(x, y, was_falling)
				
				if res.moved:
					moved = true
					# Marcar la NUEVA posición como procesada para este tick
					var new_key = str(res.new_pos.x) + "," + str(res.new_pos.y)
					processed_this_tick[new_key] = true
					# Transferir o actualizar visuales
					var visual_data = rock_visuals.get(key, {
						"visual_pos": grid_to_world(Vector2i(x,y)),
						"rotation": 0.0
					})
					if res.rotated:
						visual_data.rotation += PI/2
					rock_visuals[new_key] = visual_data
					if new_key != key:
						rock_visuals.erase(key)
					
					# Si se movió hacia abajo, sigue cayendo
					if res.new_pos.y > y:
						next_falling_rocks[new_key] = true
	
	falling_rocks = next_falling_rocks
	if moved:
		queue_redraw()

func _try_fall_rock(x: int, y: int, was_falling: bool) -> Dictionary:
	var result = {"moved": false, "new_pos": Vector2i(x, y), "rotated": false}
	
	# Regla 1: Caída directa si hay espacio vacío debajo
	if y + 1 < grid_height and grid[y + 1][x] == TileType.EMPTY:
		var dest = Vector2i(x, y + 1)
		
		# REGLA AFINADA: Si NO estaba cayendo, y el jugador está en el destino, 
		# el jugador la sostiene (no empieza a caer).
		if not was_falling and player_grid_pos == dest:
			return result
		
		# Si YA estaba cayendo y el jugador está en el camino: CRUSH
		if player_grid_pos == dest:
			_player_crushed("CAÍDA DIRECTA")
		
		grid[dest.y][dest.x] = TileType.PIEDRA
		grid[y][x] = TileType.EMPTY
		result.moved = true
		result.new_pos = dest
		return result
	
	# Regla 2: Deslizamiento lateral (solo sobre otras piedras)
	if y + 1 < grid_height and grid[y + 1][x] == TileType.PIEDRA:
		# Intentar izquierda
		if x > 0 and grid[y][x - 1] == TileType.EMPTY and grid[y + 1][x - 1] == TileType.EMPTY:
			var dest = Vector2i(x - 1, y + 1)
			
			# Verificar crush si el jugador está en el destino
			if player_grid_pos == dest:
				_player_crushed("DESLIZAMIENTO IZQUIERDA")
			
			grid[dest.y][dest.x] = TileType.PIEDRA
			grid[y][x] = TileType.EMPTY
			result.moved = true
			result.new_pos = dest
			result.rotated = true
			return result
		
		# Intentar derecha
		if x < grid_width - 1 and grid[y][x + 1] == TileType.EMPTY and grid[y + 1][x + 1] == TileType.EMPTY:
			var dest = Vector2i(x + 1, y + 1)
			
			# Verificar crush si el jugador está en el destino
			if player_grid_pos == dest:
				_player_crushed("DESLIZAMIENTO DERECHA")
				
			grid[dest.y][dest.x] = TileType.PIEDRA
			grid[y][x] = TileType.EMPTY
			result.moved = true
			result.new_pos = dest
			result.rotated = true
			return result
			
	return result

func _player_crushed(reason: String = ""):
	if is_player_dead:
		return
	is_player_dead = true
	
	print("¡JUGADOR APLASTADO! Razón: ", reason, " en posición: ", player_grid_pos)
	
	# Feedback visual inmediato
	queue_redraw()
	
	# Terminar inmediatamente (o con un frame de delay para ver el impacto)
	await get_tree().process_frame
	GameManager.return_to_overworld()
