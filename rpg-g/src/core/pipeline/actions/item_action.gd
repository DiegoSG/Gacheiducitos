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
		emit_game_event(on_fail_event)
		finished.emit()
		return

	if not item or item.id.is_empty() or amount <= 0:
		push_warning("ItemAction: Ítem no configurado o cantidad inválida.")
		emit_game_event(on_fail_event)
		finished.emit()
		return

	if operation == "add":
		Inventory.add_item(item.id, amount)
		if show_feedback:
			LootFeedbackManager.trigger_toast(item, amount)
		emit_game_event(on_success_event)
	elif operation == "remove":
		# remove_item es atómico: si no alcanza la cantidad no quita nada y devuelve false
		if Inventory.remove_item(item.id, amount):
			emit_game_event(on_success_event)
		else:
			emit_game_event(on_fail_event)

	finished.emit()
