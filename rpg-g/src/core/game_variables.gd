extends Node

## Almacén global de variables de juego con acceso por ruta ("flag.x", "quest.id", "player.gold", "item.id", "status.id").
## Solo las rutas "flag.*" son escribibles; el resto son de solo lectura y reflejan otros sistemas.

signal variable_changed(path: String, value: Variant)
signal quest_started(quest_id: String)
signal quest_completed(quest_id: String)

const FLAG_PREFIX: String = "flag."

var flags: Dictionary = {}
var quests: Dictionary = {}

func _ready() -> void:
	_load_defaults()
	_connect_sources()

func _load_defaults() -> void:
	const DEFAULTS_PATH: String = "res://src/core/data/narrative_defaults.gd"
	if ResourceLoader.exists(DEFAULTS_PATH):
		var script: GDScript = load(DEFAULTS_PATH)
		if script and "DEFAULTS" in script:
			var defaults: Dictionary = script.DEFAULTS
			for key: String in defaults:
				if not flags.has(key):
					flags[key] = defaults[key]

## Reemite como variable_changed los cambios de los sistemas de origen.
func _connect_sources() -> void:
	PlayerStats.health_changed.connect(_on_health_changed)
	PlayerStats.gold_changed.connect(_on_gold_changed)
	PlayerStats.stats_changed.connect(_on_stats_changed)
	Inventory.inventory_changed.connect(_on_inventory_changed)

func _on_health_changed(current: int, _max_hp: int) -> void:
	variable_changed.emit("player.health", current)

func _on_gold_changed(amount: int) -> void:
	variable_changed.emit("player.gold", amount)

func _on_stats_changed() -> void:
	variable_changed.emit("player.stats", null)

func _on_inventory_changed() -> void:
	variable_changed.emit("item", null)

# --- API por rutas ---

func get_var(path: String, default: Variant = null) -> Variant:
	if path.begins_with(FLAG_PREFIX):
		return flags.get(path.substr(FLAG_PREFIX.length()), default)
	var dot: int = path.find(".")
	if dot < 0:
		return default
	var root_key: String = path.substr(0, dot)
	var sub: String = path.substr(dot + 1)
	match root_key:
		"quest":
			return String(quests.get(sub, ""))
		"player":
			return _get_player_var(sub, default)
		"item":
			return Inventory.get_item_count(sub)
		"status":
			return PlayerStats.has_status(sub)
	return default

func _get_player_var(stat: String, default: Variant) -> Variant:
	match stat:
		"health":
			return PlayerStats.health
		"max_health":
			return PlayerStats.get_max_health()
		"gold":
			return PlayerStats.gold
		"speed":
			return PlayerStats.get_speed_multiplier()
		"strength":
			return PlayerStats.get_strength()
		"resistance":
			return PlayerStats.get_resistance()
	return default


func has_var(path: String) -> bool:
	if path.begins_with(FLAG_PREFIX):
		return flags.has(path.substr(FLAG_PREFIX.length()))
	var dot: int = path.find(".")
	if dot < 0:
		return false
	var sub: String = path.substr(dot + 1)
	match path.substr(0, dot):
		"quest":
			return quests.has(sub)
		"player":
			return sub in ["health", "max_health", "gold", "speed", "strength", "resistance"]
		"item", "status":
			return not sub.is_empty()
	return false

func set_var(path: String, value: Variant) -> void:
	if not _is_writable(path, "set_var"):
		return
	flags[path.substr(FLAG_PREFIX.length())] = value
	variable_changed.emit(path, value)

func add_var(path: String, amount: float) -> void:
	if not _is_writable(path, "add_var"):
		return
	var current: Variant = get_var(path, 0)
	var base: float = float(current) if (current is int or current is float) else 0.0
	var result: float = base + amount
	# Mantiene enteros cuando ambos operandos lo son
	if (current == null or current is int) and is_equal_approx(amount, roundf(amount)):
		set_var(path, int(result))
	else:
		set_var(path, result)

func toggle_var(path: String) -> void:
	if not _is_writable(path, "toggle_var"):
		return
	set_var(path, not bool(get_var(path, false)))

func _is_writable(path: String, caller: String) -> bool:
	if path.begins_with(FLAG_PREFIX) and path.length() > FLAG_PREFIX.length():
		return true
	push_warning("GameVariables.%s: la ruta '%s' no es escribible (solo flag.*)." % [caller, path])
	return false

# --- Misiones ---

func start_quest(quest_id: String) -> void:
	if not quests.has(quest_id):
		quests[quest_id] = "active"
		AudioManager.play_ui(&"sfx_quest_started")
		quest_started.emit(quest_id)
		variable_changed.emit("quest." + quest_id, "active")

func complete_quest(quest_id: String) -> void:
	if quests.get(quest_id) == "active":
		quests[quest_id] = "completed"
		AudioManager.play_ui(&"sfx_quest_completed")
		quest_completed.emit(quest_id)
		variable_changed.emit("quest." + quest_id, "completed")

func is_quest_completed(quest_id: String) -> bool:
	return quests.get(quest_id) == "completed"

func is_quest_active(quest_id: String) -> bool:
	return quests.get(quest_id) == "active"

# --- Snapshots ---

func create_snapshot() -> Dictionary:
	return {
		"flags": flags.duplicate(true),
		"quests": quests.duplicate(true)
	}

func restore_snapshot(snapshot: Dictionary) -> void:
	if snapshot.has("flags"):
		flags = snapshot["flags"].duplicate(true)
	if snapshot.has("quests"):
		quests = snapshot["quests"].duplicate(true)
