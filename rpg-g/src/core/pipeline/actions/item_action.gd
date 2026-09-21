class_name ItemAction
extends ActionResource

## Acción que añade o remueve ítems del inventario global.
## Compatible con el pipeline de GameTrigger, DialogueEvent y OnEventListener.

@export_group("Item Configuration")
## Recurso visual del ítem a añadir o remover
@export var item: ItemData = null
## Cantidad de ítems involucrados
@export_range(1, 999) var amount: int = 1
## Operación: 'add' (sumar al inventario) o 'remove' (sustracción atómica)
@export_enum("add", "remove") var operation: String = "add"
## Si es true, muestra la notificación toast en el HUD al recibir el ítem
@export var show_feedback: bool = true

@export_group("Event Triggers (Opcionales)")
## Evento global disparado vía GameManager.trigger_event si la acción se completa con éxito.
@export var on_success_event: String = ""
## Evento global disparado vía GameManager.trigger_event si la acción falla (ej. no alcanza la cantidad al remover).
@export var on_fail_event: String = ""

func get_action_name() -> String:
	var item_name: String = item.id if item and not item.id.is_empty() else "None"
	return "ItemAction (%s %s x%d)" % [operation, item_name, amount]

func execute(trigger_node: Node) -> void:
	if not trigger_node:
		push_warning("ItemAction: trigger_node es null.")
		_trigger_event(trigger_node, on_fail_event)
		finished.emit()
		return

	if not item or item.id.is_empty() or amount <= 0:
		push_warning("ItemAction: Ítem no configurado o cantidad inválida.")
		_trigger_event(trigger_node, on_fail_event)
		finished.emit()
		return

	var inv = trigger_node.get_node_or_null("/root/Inventory")
	if not inv:
		push_warning("ItemAction: Autoload /root/Inventory no encontrado.")
		_trigger_event(trigger_node, on_fail_event)
		finished.emit()
		return

	if operation == "add":
		inv.add_item(item.id, amount)
		if show_feedback:
			LootFeedbackManager.trigger_toast(item, amount)
		_trigger_event(trigger_node, on_success_event)
	elif operation == "remove":
		if inv.has_method("has_item_amount") and inv.has_item_amount(item.id, amount):
			inv.remove_item(item.id, amount)
			_trigger_event(trigger_node, on_success_event)
		else:
			# Fallo: no tiene el ítem o no alcanza la cantidad requerida (no se quita nada)
			_trigger_event(trigger_node, on_fail_event)

	finished.emit()

func _trigger_event(node: Node, event_name: String) -> void:
	if event_name.is_empty() or not node:
		return
	var gm = node.get_node_or_null("/root/GameManager")
	if gm and gm.has_method("trigger_event"):
		gm.trigger_event(event_name)
