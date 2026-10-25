class_name HealthAction
extends ActionResource

## Acción que modifica la salud del jugador en PlayerStats (curación o daño).
## Compatible con el pipeline de GameTrigger, DialogueEvent y OnEventListener.

@export_group("Health Configuration")
## Si es true, ignora 'amount' y cura al jugador hasta el máximo (max_health).
@export var full_heal: bool = false
## Cantidad de salud a modificar (si full_heal es false).
## Valores positivos (+X) curan al jugador.
## Valores negativos (-X) dañan al jugador.
@export var amount: int = 10

func get_action_name() -> String:
	if full_heal:
		return "HealthAction (Full Heal)"
	return "HealthAction (%+d HP)" % amount

func execute(trigger_node: Node) -> void:
	if not trigger_node:
		push_warning("HealthAction: trigger_node es null.")
		finished.emit()
		return

	if full_heal:
		PlayerStats.full_heal()
	elif amount > 0:
		PlayerStats.heal(amount)
	elif amount < 0:
		PlayerStats.take_damage(absi(amount))

	finished.emit()
