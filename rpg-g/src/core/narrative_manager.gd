extends Node

## Manages global game variables, quest states, and narrative flags.

signal flag_changed(flag: String, value: Variant)
signal quest_started(quest_id: String)
signal quest_completed(quest_id: String)

var flags: Dictionary = {}
var quests: Dictionary = {}

func _ready() -> void:
	_load_defaults()

func _load_defaults() -> void:
	const DEFAULTS_PATH: String = "res://src/core/data/narrative_defaults.gd"
	if ResourceLoader.exists(DEFAULTS_PATH):
		var script: GDScript = load(DEFAULTS_PATH)
		if script and "DEFAULTS" in script:
			var defaults: Dictionary = script.DEFAULTS
			for key: String in defaults:
				if not flags.has(key):
					flags[key] = defaults[key]
			print("NarrativeManager: Loaded %d default flags" % defaults.size())

func set_flag(flag: String, value: Variant) -> void:
	flags[flag] = value
	flag_changed.emit(flag, value)
	print("NarrativeManager: Set flag %s = %s" % [flag, value])

func get_flag(flag: String, default: Variant = null) -> Variant:
	return flags.get(flag, default)

func start_quest(quest_id: String) -> void:
	if not quests.has(quest_id):
		quests[quest_id] = "active"
		quest_started.emit(quest_id)
		print("NarrativeManager: Quest %s started" % quest_id)

func complete_quest(quest_id: String) -> void:
	if quests.get(quest_id) == "active":
		quests[quest_id] = "completed"
		quest_completed.emit(quest_id)
		print("NarrativeManager: Quest %s completed" % quest_id)

func is_quest_completed(quest_id: String) -> bool:
	return quests.get(quest_id) == "completed"

func is_quest_active(quest_id: String) -> bool:
	return quests.get(quest_id) == "active"

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
	print("NarrativeManager: Snapshot restaurado")
