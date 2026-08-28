extends Node

signal health_changed(current: int, max_hp: int)
signal gold_changed(amount: int)

@export var max_health: int = 100
@onready var health: int = max_health:
	set(value):
		health = clampi(value, 0, max_health)
		health_changed.emit(health, max_health)

@export var gold: int = 0:
	set(value):
		gold = maxi(0, value)
		gold_changed.emit(gold)

func add_gold(amount: int) -> void:
	self.gold += amount
	print("Gold added: ", amount, " | Total: ", gold)

func take_damage(amount: int) -> void:
	self.health -= amount
	print("Player took damage: ", amount, " | HP: ", health)

func heal(amount: int) -> void:
	self.health += amount
	print("Player healed: ", amount, " | HP: ", health)
