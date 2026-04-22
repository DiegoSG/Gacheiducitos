class_name RunTriggerAction
extends ActionResource
## Start another GameTrigger remotely.

## The NodePath towards the GameTrigger you want to execute remotely.
@export var target_trigger: NodePath

func get_action_name() -> String:
	return "RunTriggerAction"

func execute(trigger_node: Node) -> void:
	if target_trigger.is_empty():
		finished.emit()
		return
		
	var t_node = trigger_node.get_node_or_null(target_trigger)
	if not t_node:
		print("RunTriggerAction: No se encontró target ", target_trigger)
		finished.emit()
		return
		
	if t_node.has_method("force_trigger"):
		t_node.force_trigger()
		
		# NOTA: RunTriggerAction sólo "llama" al otro trigger, no espera a que 
		# todo el array del otro trigger termine para continuar. Es como apretar un interruptor.
		
	finished.emit()
