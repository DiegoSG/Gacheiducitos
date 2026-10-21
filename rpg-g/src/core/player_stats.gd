extends Node

signal health_changed(current: int, max_hp: int)
signal gold_changed(amount: int)
signal player_died
signal status_applied(effect: StatusEffectData)
signal status_removed(status_id: String)
signal stats_changed

const MIN_SPEED_MULTIPLIER: float = 0.1
## Fraction of max health below which the low-health warning sounds.
const LOW_HEALTH_RATIO: float = 0.25

## Prevents HUD sounds when restoring a snapshot.
var _is_restoring: bool = false

# The setters are the ONLY place that emits health_changed / player_died / gold_changed.
## BASE max health (statuses can modify it: see get_max_health()).
@export var max_health: int = 4:
	set(value):
		var prev_max_health: int = max_health
		max_health = maxi(1, value)
		if max_health != prev_max_health and not _is_restoring:
			AudioManager.play_ui(&"sfx_hud_max_health_changed")
		# Reassigning health goes through its setter, which emits health_changed with the new max
		health = health

var health: int = 4:
	set(value):
		var prev_health: int = health
		health = clampi(value, 0, get_max_health())
		if health != prev_health and not _is_restoring:
			AudioManager.play_ui(&"sfx_hud_health_changed")
			if health > 0 and is_low_health(health) and not is_low_health(prev_health):
				AudioManager.play_sfx(&"sfx_player_low_health")
		health_changed.emit(health, get_max_health())
		if health <= 0 and prev_health > 0:
			player_died.emit()

@export var gold: int = 0:
	set(value):
		var prev_gold: int = gold
		gold = maxi(0, value)
		if gold != prev_gold and not _is_restoring:
			AudioManager.play_ui(&"sfx_hud_gold_changed")
		gold_changed.emit(gold)

@export_group("Base Stats")
## Base strength = player attack damage.
@export var base_strength: int = 1
## Base resistance: subtracts damage from each hit received (the resulting minimum is 0).
@export var base_resistance: int = 0

# Active statuses: each entry is {"effect": StatusEffectData, "remaining": float, "tick_timer": float}
var _active: Array[Dictionary] = []
# Last applied status (to tint the HUD)
var _last_applied: StatusEffectData = null

func _process(delta: float) -> void:
	if _active.is_empty():
		return
	var expired: Array[String] = []
	for entry: Dictionary in _active.duplicate():
		var effect: StatusEffectData = entry["effect"]
		if effect.tick_interval > 0.0 and health > 0:
			entry["tick_timer"] = float(entry["tick_timer"]) + delta
			while float(entry["tick_timer"]) >= effect.tick_interval:
				entry["tick_timer"] = float(entry["tick_timer"]) - effect.tick_interval
				_apply_status_tick(effect)
		if effect.duration > 0.0:
			entry["remaining"] = float(entry["remaining"]) - delta
			if float(entry["remaining"]) <= 0.0:
				expired.append(effect.id)
	for status_id: String in expired:
		cure_status(status_id)

# --- Statuses ---------------------------------------------------------------

## Applies a status. If it is already active, resets its duration.
func apply_status(effect: StatusEffectData) -> void:
	if effect == null or effect.id.is_empty():
		return
	var entry: Dictionary = _find_entry(effect.id)
	if entry.is_empty():
		_active.append({"effect": effect, "remaining": effect.duration, "tick_timer": 0.0})
	else:
		entry["effect"] = effect
		entry["remaining"] = effect.duration
	_last_applied = effect
	AudioManager.play_sfx(&"sfx_status_applied")
	status_applied.emit(effect)
	_on_stats_modified()

func cure_status(status_id: String) -> void:
	var entry: Dictionary = _find_entry(status_id)
	if entry.is_empty():
		return
	_active.erase(entry)
	if _last_applied != null and _last_applied.id == status_id:
		_last_applied = _active.back()["effect"] if not _active.is_empty() else null
	AudioManager.play_sfx(&"sfx_status_removed")
	status_removed.emit(status_id)
	_on_stats_modified()

func cure_all_statuses() -> void:
	var ids: Array[String] = []
	for entry: Dictionary in _active:
		ids.append((entry["effect"] as StatusEffectData).id)
	for status_id: String in ids:
		cure_status(status_id)

func has_status(status_id: String) -> bool:
	return not _find_entry(status_id).is_empty()

func get_active_statuses() -> Array[StatusEffectData]:
	var result: Array[StatusEffectData] = []
	for entry: Dictionary in _active:
		result.append(entry["effect"])
	return result

## Last applied status that is still active (null if there is none).
func get_last_status() -> StatusEffectData:
	return _last_applied

func _find_entry(status_id: String) -> Dictionary:
	for entry: Dictionary in _active:
		if (entry["effect"] as StatusEffectData).id == status_id:
			return entry
	return {}

func _on_stats_modified() -> void:
	# Reassigning health clamps it to the effective max and emits health_changed
	health = health
	stats_changed.emit()

# Periodic damage/healing from a status: ignores resistance.
func _apply_status_tick(effect: StatusEffectData) -> void:
	if effect.health_per_tick == 0:
		return
	AudioManager.play_sfx(&"sfx_status_tick")
	var new_health: int = health + effect.health_per_tick
	if effect.health_per_tick < 0 and not effect.can_kill:
		new_health = maxi(new_health, mini(health, 1))
	health = new_health

# --- Effective stats -------------------------------------------------------

func get_speed_multiplier() -> float:
	var result: float = 1.0
	for entry: Dictionary in _active:
		result *= (entry["effect"] as StatusEffectData).speed_multiplier
	return maxf(result, MIN_SPEED_MULTIPLIER)

func get_strength() -> int:
	var result: int = base_strength
	for entry: Dictionary in _active:
		result += (entry["effect"] as StatusEffectData).strength_bonus
	return maxi(result, 0)

func get_resistance() -> int:
	var result: int = base_resistance
	for entry: Dictionary in _active:
		result += (entry["effect"] as StatusEffectData).resistance_bonus
	return result

## Effective max health (base + status bonuses, minimum 1).
func get_max_health() -> int:
	var result: int = max_health
	for entry: Dictionary in _active:
		result += (entry["effect"] as StatusEffectData).max_health_bonus
	return maxi(result, 1)

# --- Health and gold ------------------------------------------------------------

func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount

## Applies damage reduced by resistance (minimum 0).
func take_damage(amount: int) -> void:
	var final_amount: int = maxi(0, amount - get_resistance())
	if final_amount <= 0:
		return
	health -= final_amount

func heal(amount: int) -> void:
	if amount <= 0:
		return
	if health < get_max_health():
		AudioManager.play_sfx(&"sfx_player_heal")
	health += amount

func full_heal() -> void:
	health = get_max_health()

func remove_gold(amount: int) -> bool:
	if amount <= 0:
		return true
	if gold < amount:
		return false
	gold -= amount
	return true


# --- Persistence ----------------------------------------------------------

func create_snapshot() -> Dictionary:
	var statuses: Array[Dictionary] = []
	for entry: Dictionary in _active:
		var effect: StatusEffectData = entry["effect"]
		if effect.resource_path.is_empty():
			continue # A status created at runtime cannot be serialized
		statuses.append({
			"path": effect.resource_path,
			"remaining": float(entry["remaining"]),
			"tick_timer": float(entry["tick_timer"])
		})
	return {
		"health": health,
		"max_health": max_health,
		"gold": gold,
		"statuses": statuses
	}

func restore_snapshot(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	# Statuses are restored first: they affect the effective max used to clamp health.
	# If the save is old (no key), the player is left with no statuses.
	_is_restoring = true
	_active.clear()
	_last_applied = null
	var saved_statuses: Array = snapshot.get("statuses", [])
	for saved: Variant in saved_statuses:
		if not saved is Dictionary:
			continue
		var effect: StatusEffectData = load(str((saved as Dictionary).get("path", ""))) as StatusEffectData
		if effect == null:
			continue
		_active.append({
			"effect": effect,
			"remaining": float((saved as Dictionary).get("remaining", effect.duration)),
			"tick_timer": float((saved as Dictionary).get("tick_timer", 0.0))
		})
		_last_applied = effect
	if snapshot.has("max_health"):
		max_health = int(snapshot["max_health"])
	if snapshot.has("health"):
		health = int(snapshot["health"])
	if snapshot.has("gold"):
		gold = int(snapshot["gold"])
	_is_restoring = false
	stats_changed.emit()

## true if the given health is in the warning zone (at least 1 point, even if max health is low).
func is_low_health(value: int) -> bool:
	return value <= maxi(1, floori(get_max_health() * LOW_HEALTH_RATIO))
