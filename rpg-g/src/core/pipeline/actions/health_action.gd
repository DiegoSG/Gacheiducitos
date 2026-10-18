class_name HealthAction
extends ActionResource

## Action that modifies the player's health in PlayerStats (healing or damage).
## Compatible with the GameTrigger, DialogueEvent and OnEventListener pipeline.

@export_group("Health Configuration")
## If true, ignores 'amount' and heals the player to the maximum (max_health).
@export var full_heal: bool = false
## Amount of health to modify (if full_heal is false).
## Positive values (+X) heal the player.
## Negative values (-X) damage the player.
@export var amount: int = 10

func get_action_name() -> String:
	if full_heal:
		return "HealthAction (Full Heal)"
	return "HealthAction (%+d HP)" % amount

func execute(trigger_node: Node) -> void:
	if not trigger_node:
		push_warning("HealthAction: trigger_node is null.")
		finished.emit()
		return

	if full_heal:
		PlayerStats.full_heal()
	elif amount > 0:
		PlayerStats.heal(amount)
	elif amount < 0:
		PlayerStats.take_damage(absi(amount))

	finished.emit()
