class_name StatusAction
extends ActionResource

## Aplica o cura estados alterados del jugador. Compatible con GameTrigger, DialogueEvent y OnEventListener.

enum Operation { APPLY, CURE }

@export var operation: Operation = Operation.APPLY
## Estado a aplicar (APPLY) o a curar por su id (CURE).
@export var status: StatusEffectData = null
## Solo CURE: si es true, cura todos los estados e ignora 'status'.
@export var cure_all: bool = false

func get_action_name() -> String:
	var status_id: String = status.id if status else "None"
	if operation == Operation.APPLY:
		return "StatusAction (Apply %s)" % status_id
	return "StatusAction (Cure %s)" % ("all" if cure_all else status_id)

func execute(_trigger_node: Node) -> void:
	if operation == Operation.APPLY:
		if status:
			PlayerStats.apply_status(status)
		else:
			push_warning("StatusAction: APPLY sin estado configurado.")
	else:
		if cure_all:
			PlayerStats.cure_all_statuses()
		elif status:
			PlayerStats.cure_status(status.id)
		else:
			push_warning("StatusAction: CURE sin estado configurado.")
	finished.emit()
