@tool
class_name MinigameAction
extends ActionResource

## Inicia un minijuego con ajustes predefinidos e introspección dinámica en el Inspector.

enum MinigameType {
	RUNNER = 0,
	EXCAVATION = 1,
	CATCHER = 2,
	SMASHER = 3,
	TRAMPOLIN = 4,
	CUSTOM_SCENE = 5
}

const MINIGAME_SCENE_PATHS = {
	MinigameType.RUNNER: "res://src/minigames/mg_runner/mg_runner_level.tscn",
	MinigameType.EXCAVATION: "res://src/minigames/mg_excavation/mg_excavation_game.tscn",
	MinigameType.CATCHER: "res://src/minigames/mg_catcher/mg_catcher_game.tscn",
	MinigameType.SMASHER: "res://src/minigames/mg_smasher/mg_smasher_game.tscn",
	MinigameType.TRAMPOLIN: "res://src/minigames/mg_trampolin/mg_trampolin.tscn"
}

## Selector principal de minijuego
@export_group("Selección de Minijuego")
@export var minigame_type: MinigameType = MinigameType.RUNNER:
	set(val):
		minigame_type = val
		notify_property_list_changed()

## Ruta de escena personalizada (solo si se selecciona CUSTOM_SCENE)
var custom_scene_path: String = ""

# --- Parámetros específicos de RUNNER ---
var runner_win_mode: int = 0: # 0: Distancia, 1: Objeto Clave
	set(val):
		runner_win_mode = val
		notify_property_list_changed()
var runner_target_distance: float = 1500.0
var runner_target_item_id: String = "ancient_map"
var runner_target_distance_range: Vector2 = Vector2(800.0, 1200.0)
var runner_speed: float = 380.0
var runner_coin_density: float = 0.55
var runner_max_coins: int = -1
var runner_item_pool: Array[String] = ["blue_potion", "red_potion", "green_herb"]
var runner_speed_increase_interval: float = 200.0
var runner_speed_increase_amount: float = 25.0
var runner_ammo_initial_distance: float = 250.0
var runner_ammo_distance_multiplier: float = 1.5

# --- Parámetros específicos de CATCHER ---
var catcher_game_mode: int = 0 # 0: COUNT, 1: TIME
var catcher_target_value: float = 5.0
var catcher_lives: int = 3
var catcher_fall_speed: float = 200.0
var catcher_spawn_rate: float = 0.8
var catcher_max_objects: int = 8
var catcher_item_pool: Array[String] = ["blue_potion", "red_potion", "green_herb"]
var catcher_critical_item_ids: Array[String] = ["falling_bomb", "falling_rock"]

# --- Parámetros específicos de EXCAVATION ---
var excavation_win_condition: int = 0 # 0: ALL_COINS, 1: TARGET_AMOUNT, 2: MISSION_ITEM
var excavation_target_amount: int = 5
var excavation_rocks: int = 10
var excavation_scale: float = 1.5
var excavation_deliver_items: bool = false
var excavation_initial_bombs: int = 1
var excavation_item_pool: Array[String] = ["blue_potion", "red_potion", "green_herb"]

# --- Parámetros específicos de SMASHER ---
var smasher_game_mode: int = 0 # 0: COUNT, 1: TIME
var smasher_target_value: float = 5.0
var smasher_initial_speed: float = 150.0
var smasher_final_speed: float = 350.0
var smasher_lives: int = 3

# --- Parámetros específicos de TRAMPOLIN ---
var trampolin_win_condition: int = 1 # 0: ALTURA, 1: ESPECIAL, 2: MONEDAS
var trampolin_target_value: float = 5.0
var trampolin_item_chance: float = 0.25
var trampolin_item_pool: Array[String] = ["blue_potion", "red_potion", "green_herb"]

# --- Rutas de retorno al Overworld ---
@export_group("Retorno al Overworld (Victoria)")
@export_file("*.tscn") var win_level_path: String = ""
@export var win_spawn_id: String = "spawn_win"

@export_group("Retorno al Overworld (Derrota)")
@export_file("*.tscn") var lose_level_path: String = ""
@export var lose_spawn_id: String = "spawn_lose"

var _raw_config: Dictionary = {}
## Diccionario de compatibilidad y ajustes manuales opcionales
@export_group("Ajustes Avanzados")
@export var config: Dictionary = {}:
	set(val):
		_raw_config = val
	get:
		var built = get_built_config()
		for k in _raw_config:
			built[k] = _raw_config[k]
		return built

var _raw_scene_path: String = ""
@export_file("*.tscn") var minigame_scene_path: String = "":
	set(val):
		_raw_scene_path = val
	get:
		if not _raw_scene_path.is_empty():
			return _raw_scene_path
		return get_minigame_scene_path()

func _get_property_list() -> Array[Dictionary]:
	var list: Array[Dictionary] = []

	if minigame_type == MinigameType.CUSTOM_SCENE:
		list.append({
			"name": "custom_scene_path",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_FILE,
			"hint_string": "*.tscn",
			"usage": PROPERTY_USAGE_DEFAULT
		})
	elif minigame_type == MinigameType.RUNNER:
		list.append({
			"name": "Runner Settings",
			"type": TYPE_NIL,
			"usage": PROPERTY_USAGE_GROUP
		})
		list.append({
			"name": "runner_win_mode",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Por Distancia (Metros):0,Por Objeto Clave (Meta):1",
			"usage": PROPERTY_USAGE_DEFAULT
		})
		if runner_win_mode == 0:
			list.append({
				"name": "runner_target_distance",
				"type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "100.0,10000.0,50.0,or_greater",
				"usage": PROPERTY_USAGE_DEFAULT
			})
		else:
			list.append({
				"name": "runner_target_item_id",
				"type": TYPE_STRING,
				"usage": PROPERTY_USAGE_DEFAULT
			})
			list.append({
				"name": "runner_target_distance_range",
				"type": TYPE_VECTOR2,
				"usage": PROPERTY_USAGE_DEFAULT
			})
		list.append({
			"name": "runner_speed",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "150.0,800.0,10.0",
			"usage": PROPERTY_USAGE_DEFAULT
		})
		list.append({
			"name": "runner_coin_density",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,1.0,0.05",
			"usage": PROPERTY_USAGE_DEFAULT
		})
		list.append({
			"name": "runner_max_coins",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "-1,200,1",
			"usage": PROPERTY_USAGE_DEFAULT
		})
		list.append({
			"name": "runner_item_pool",
			"type": TYPE_ARRAY,
			"hint": PROPERTY_HINT_TYPE_STRING,
			"hint_string": "%d:" % TYPE_STRING,
			"usage": PROPERTY_USAGE_DEFAULT
		})
		list.append({
			"name": "runner_speed_increase_interval",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "50.0,2000.0,25.0",
			"usage": PROPERTY_USAGE_DEFAULT
		})
		list.append({
			"name": "runner_speed_increase_amount",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "5.0,100.0,5.0",
			"usage": PROPERTY_USAGE_DEFAULT
		})
		list.append({
			"name": "runner_ammo_initial_distance",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "50.0,2000.0,25.0",
			"usage": PROPERTY_USAGE_DEFAULT
		})
		list.append({
			"name": "runner_ammo_distance_multiplier",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "1.0,3.0,0.1",
			"usage": PROPERTY_USAGE_DEFAULT
		})
	elif minigame_type == MinigameType.CATCHER:
		list.append({
			"name": "Catcher Settings",
			"type": TYPE_NIL,
			"usage": PROPERTY_USAGE_GROUP
		})
		list.append({
			"name": "catcher_game_mode",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Puntos Objetivo (COUNT):0,Sobrevivir Tiempo (TIME):1",
			"usage": PROPERTY_USAGE_DEFAULT
		})
		list.append({
			"name": "catcher_target_value",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "1.0,120.0,1.0",
			"usage": PROPERTY_USAGE_DEFAULT
		})
		list.append({
			"name": "catcher_lives",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "1,10,1",
			"usage": PROPERTY_USAGE_DEFAULT
		})
		list.append({
			"name": "catcher_fall_speed",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "100.0,600.0,10.0",
			"usage": PROPERTY_USAGE_DEFAULT
		})
		list.append({
			"name": "catcher_spawn_rate",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.2,3.0,0.1",
			"usage": PROPERTY_USAGE_DEFAULT
		})
		list.append({
			"name": "catcher_item_pool",
			"type": TYPE_ARRAY,
			"hint": PROPERTY_HINT_TYPE_STRING,
			"hint_string": "%d:" % TYPE_STRING,
			"usage": PROPERTY_USAGE_DEFAULT
		})
		list.append({
			"name": "catcher_critical_item_ids",
			"type": TYPE_ARRAY,
			"hint": PROPERTY_HINT_TYPE_STRING,
			"hint_string": "%d:" % TYPE_STRING,
			"usage": PROPERTY_USAGE_DEFAULT
		})
	elif minigame_type == MinigameType.EXCAVATION:
		list.append({
			"name": "Excavation Settings",
			"type": TYPE_NIL,
			"usage": PROPERTY_USAGE_GROUP
		})
		list.append({
			"name": "excavation_win_condition",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Todas las Monedas:0,Cantidad Específica:1,Item de Misión:2",
			"usage": PROPERTY_USAGE_DEFAULT
		})
		list.append({
			"name": "excavation_target_amount",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "1,50,1",
			"usage": PROPERTY_USAGE_DEFAULT
		})
		list.append({
			"name": "excavation_rocks",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0,30,1",
			"usage": PROPERTY_USAGE_DEFAULT
		})
		list.append({
			"name": "excavation_scale",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "1.0,3.0,0.1",
			"usage": PROPERTY_USAGE_DEFAULT
		})
		list.append({
			"name": "excavation_deliver_items",
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT
		})
		list.append({
			"name": "excavation_initial_bombs",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0,10,1",
			"usage": PROPERTY_USAGE_DEFAULT
		})
		list.append({
			"name": "excavation_item_pool",
			"type": TYPE_ARRAY,
			"hint": PROPERTY_HINT_TYPE_STRING,
			"hint_string": "%d:" % TYPE_STRING,
			"usage": PROPERTY_USAGE_DEFAULT
		})
	elif minigame_type == MinigameType.SMASHER:
		list.append({
			"name": "Smasher Settings",
			"type": TYPE_NIL,
			"usage": PROPERTY_USAGE_GROUP
		})
		list.append({
			"name": "smasher_game_mode",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Dianas Golpeadas (COUNT):0,Tiempo Límite (TIME):1",
			"usage": PROPERTY_USAGE_DEFAULT
		})
		list.append({
			"name": "smasher_target_value",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "1.0,60.0,1.0",
			"usage": PROPERTY_USAGE_DEFAULT
		})
		list.append({
			"name": "smasher_initial_speed",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "50.0,400.0,10.0",
			"usage": PROPERTY_USAGE_DEFAULT
		})
		list.append({
			"name": "smasher_final_speed",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "100.0,800.0,10.0",
			"usage": PROPERTY_USAGE_DEFAULT
		})
		list.append({
			"name": "smasher_lives",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "1,10,1",
			"usage": PROPERTY_USAGE_DEFAULT
		})
	elif minigame_type == MinigameType.TRAMPOLIN:
		list.append({
			"name": "Trampolin Settings",
			"type": TYPE_NIL,
			"usage": PROPERTY_USAGE_GROUP
		})
		list.append({
			"name": "trampolin_win_condition",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Altura Alcanzada:0,Plataforma Especial:1,Monedas Recolectadas:2",
			"usage": PROPERTY_USAGE_DEFAULT
		})
		list.append({
			"name": "trampolin_target_value",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "1.0,1000.0,1.0",
			"usage": PROPERTY_USAGE_DEFAULT
		})
		list.append({
			"name": "trampolin_item_chance",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,1.0,0.05",
			"usage": PROPERTY_USAGE_DEFAULT
		})
		list.append({
			"name": "trampolin_item_pool",
			"type": TYPE_ARRAY,
			"hint": PROPERTY_HINT_TYPE_STRING,
			"hint_string": "%d:" % TYPE_STRING,
			"usage": PROPERTY_USAGE_DEFAULT
		})

	return list

func get_minigame_scene_path() -> String:
	if minigame_type == MinigameType.CUSTOM_SCENE:
		return custom_scene_path
	if MINIGAME_SCENE_PATHS.has(minigame_type):
		return MINIGAME_SCENE_PATHS[minigame_type]
	if not minigame_scene_path.is_empty():
		return minigame_scene_path
	return ""

func get_built_config() -> Dictionary:
	var c: Dictionary = {}
	match minigame_type:
		MinigameType.RUNNER:
			c["win_condition"] = runner_win_mode
			if runner_win_mode == 0:
				c["target_value"] = runner_target_distance
			else:
				c["target_item_id"] = runner_target_item_id
				c["target_distance_range"] = runner_target_distance_range
			c["run_speed"] = runner_speed
			c["coin_density"] = runner_coin_density
			c["max_coins"] = runner_max_coins
			c["item_pool"] = runner_item_pool
			c["speed_increase_interval"] = runner_speed_increase_interval
			c["speed_increase_amount"] = runner_speed_increase_amount
			c["ammo_spawn_initial_distance"] = runner_ammo_initial_distance
			c["ammo_spawn_distance_multiplier"] = runner_ammo_distance_multiplier
		MinigameType.CATCHER:
			c["game_mode"] = "TIME" if catcher_game_mode == 1 else "COUNT"
			c["target_value"] = catcher_target_value
			c["lives"] = catcher_lives
			c["base_fall_speed"] = catcher_fall_speed
			c["spawn_rate"] = catcher_spawn_rate
			c["max_falling_objects"] = catcher_max_objects
			c["item_pool"] = catcher_item_pool
			c["critical_item_ids"] = catcher_critical_item_ids
		MinigameType.EXCAVATION:
			c["win_condition"] = excavation_win_condition
			c["target_amount"] = excavation_target_amount
			c["rocks"] = excavation_rocks
			c["escala"] = excavation_scale
			c["deliver_items"] = excavation_deliver_items
			c["initial_bombs"] = excavation_initial_bombs
			c["item_pool"] = excavation_item_pool
		MinigameType.SMASHER:
			c["game_mode"] = "TIME" if smasher_game_mode == 1 else "COUNT"
			c["target_value"] = smasher_target_value
			c["initial_speed"] = smasher_initial_speed
			c["final_speed"] = smasher_final_speed
			c["lives"] = smasher_lives
		MinigameType.TRAMPOLIN:
			c["win_condition"] = trampolin_win_condition
			c["target_value"] = trampolin_target_value
			c["item_spawn_chance"] = trampolin_item_chance
			c["item_pool"] = trampolin_item_pool
		MinigameType.CUSTOM_SCENE:
			pass

	# Si se especificaron claves en el diccionario config legacy/avanzado, tienen precedencia
	for k in _raw_config:
		c[k] = _raw_config[k]

	return c

func get_action_name() -> String:
	var type_name = MinigameType.keys()[minigame_type] if minigame_type < MinigameType.size() else "Custom"
	return "MinigameAction: %s" % type_name

func execute(trigger_node: Node) -> void:
	var tree = trigger_node.get_tree()
	var game_manager = tree.root.get_node_or_null("GameManager")
	
	if game_manager:
		var target_scene = get_minigame_scene_path()
		if target_scene.is_empty():
			push_error("MinigameAction: No target scene specified for %s" % get_action_name())
			finished.emit()
			return

		var final_config = get_built_config()
		final_config["win_level_path"] = win_level_path
		final_config["win_spawn_id"] = win_spawn_id
		final_config["lose_level_path"] = lose_level_path
		final_config["lose_spawn_id"] = lose_spawn_id
		
		game_manager.minigame_config = final_config
		game_manager.load_minigame(target_scene)
	else:
		print("MinigameAction: GameManager not found!")
		
	finished.emit()
