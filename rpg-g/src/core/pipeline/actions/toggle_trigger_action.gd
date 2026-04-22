class_name ToggleTriggerAction
extends ActionResource

## Enables or Disables another GameTrigger's collision functionality remotely.

## The NodePath towards the GameTrigger you want to toggle.
@export var target_trigger: NodePath

## True to Enable the trigger, False to Disable it.
@export var is_enabled: bool = true

func get_action_name() -> String:
	return "ToggleTrigger (%s)" % ["ON" if is_enabled else "OFF"]

func execute(trigger_node: Node) -> void:
	if target_trigger.is_empty():
		finished.emit()
		return
		
	var t_node = trigger_node.get_node_or_null(target_trigger)
	if not t_node:
		print("ToggleTriggerAction: No se encontró target ", target_trigger)
		finished.emit()
		return
		
	if t_node is Area2D:
		t_node.set_deferred("monitoring", is_enabled)
		t_node.set_deferred("monitorable", is_enabled)
		
	finished.emit()
