class_name ActionRunner
extends RefCounted

## Ejecuta una lista de ActionResource en orden respetando wait_to_finish.
## Punto único de ejecución para GameTrigger, DialogueEvent, PressurePlate y SwitchInteractable.

## Ejecuta [param actions] en orden usando [param context] como nodo ejecutor.
## Si la acción tiene wait_to_finish = true espera a su señal finished antes de continuar;
## si es false la dispara y pasa a la siguiente sin bloquear.
## Si el contexto sale del árbol (o se libera) mientras se espera, la secuencia se aborta.
static func run(actions: Array[ActionResource], context: Node) -> void:
	var is_first: bool = true
	for act: ActionResource in actions:
		if act == null:
			continue
		if not is_first and not _is_context_alive(context):
			return
		is_first = false

		if not act.wait_to_finish:
			act.execute(context)
			continue

		var state: Dictionary = {"waiting": true}
		var on_action_done: Callable = func() -> void: state.waiting = false
		act.finished.connect(on_action_done, CONNECT_ONE_SHOT)
		act.execute(context)

		while state.waiting:
			if not _is_context_alive(context):
				if act.finished.is_connected(on_action_done):
					act.finished.disconnect(on_action_done)
				return
			await context.get_tree().process_frame

static func _is_context_alive(context: Node) -> bool:
	return is_instance_valid(context) and context.is_inside_tree()
