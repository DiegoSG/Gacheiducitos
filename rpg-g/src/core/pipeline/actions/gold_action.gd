class_name GoldAction
extends ActionResource

## Acción que añade o sustrae monedas de oro del jugador en PlayerStats.
## Compatible con el pipeline de GameTrigger, DialogueEvent y OnEventListener.

@export_group("Gold Configuration")
## Cantidad de oro a sumar o restar
@export_range(1, 99999) var amount: int = 10
## Operación: 'add' (sumar oro) o 'remove' (sustracción atómica)
@export_enum("add", "remove") var operation: String = "add"
## Si es true, muestra la notificación toast en el HUD al recibir el oro
@export var show_feedback: bool = true

@export_group("Event Triggers (Opcionales)")
## Evento global disparado vía GameManager.trigger_event si la acción se completa con éxito.
@export var on_success_event: String = ""
## Evento global disparado vía GameManager.trigger_event si no alcanza el oro para pagar.
@export var on_fail_event: String = ""

func get_action_name() -> String:
	return "GoldAction (%s %d oro)" % [operation, amount]

func execute(trigger_node: Node) -> void:
	if not trigger_node:
		push_warning("GoldAction: trigger_node es null.")
		emit_game_event(on_fail_event)
		finished.emit()
		return

	if amount <= 0:
		push_warning("GoldAction: amount debe ser mayor a 0.")
		emit_game_event(on_fail_event)
		finished.emit()
		return

	if operation == "add":
		PlayerStats.add_gold(amount)
		if show_feedback:
			var coin_res: ItemData = ItemDatabase.get_item(Inventory.GOLD_ITEM_ID)
			if coin_res:
				LootFeedbackManager.trigger_toast(coin_res, amount)
		emit_game_event(on_success_event)
	elif operation == "remove":
		if PlayerStats.remove_gold(amount):
			emit_game_event(on_success_event)
		else:
			# Fallo: no alcanza el oro (no se descuenta nada)
			emit_game_event(on_fail_event)

	finished.emit()
