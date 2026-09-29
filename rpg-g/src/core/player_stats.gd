extends Node

signal health_changed(current: int, max_hp: int)
signal gold_changed(amount: int)
signal player_died

# Los setters son el UNICO lugar que emite health_changed / player_died / gold_changed.
@export var max_health: int = 4:
	set(value):
		max_health = maxi(1, value)
		# Reasignar health pasa por su setter, que emite health_changed con el nuevo maximo
		health = clampi(health, 0, max_health)

var health: int = 4:
	set(value):
		var prev_health: int = health
		health = clampi(value, 0, max_health)
		health_changed.emit(health, max_health)
		if health <= 0 and prev_health > 0:
			player_died.emit()

@export var gold: int = 0:
	set(value):
		gold = maxi(0, value)
		gold_changed.emit(gold)

func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	print("Gold added: ", amount, " | Total: ", gold)

func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	health -= amount
	print("Player took damage: ", amount, " | HP: ", health)

func heal(amount: int) -> void:
	if amount <= 0:
		return
	health += amount
	print("Player healed: ", amount, " | HP: ", health)

func full_heal() -> void:
	health = max_health
	print("Player full healed | HP: ", health)

func remove_gold(amount: int) -> bool:
	if amount <= 0:
		return true
	if gold < amount:
		return false
	gold -= amount
	print("Gold removed: ", amount, " | Total: ", gold)
	return true

func create_snapshot() -> Dictionary:
	return {
		"health": health,
		"max_health": max_health,
		"gold": gold
	}

func restore_snapshot(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	if snapshot.has("max_health"):
		max_health = int(snapshot["max_health"])
	if snapshot.has("health"):
		health = int(snapshot["health"])
	if snapshot.has("gold"):
		gold = int(snapshot["gold"])
	print("PlayerStats: Snapshot restaurado -> HP: ", health, "/", max_health, " | Oro: ", gold)
