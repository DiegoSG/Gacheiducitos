class_name DoorAction
extends ActionResource

## Modifica el estado de un LevelPortal en el mapa (bloquear, desbloquear, activar, desactivar).

enum DoorOperation {
	UNLOCK,          ## Desbloquea la puerta (quita el candado)
	LOCK,            ## Bloquea la puerta con candado
	ACTIVATE,        ## Habilita el portal/puerta
	DEACTIVATE,      ## Deshabilita el portal/puerta
	TOGGLE_LOCK,     ## Alterna entre bloqueada y desbloqueada
	TOGGLE_ACTIVE    ## Alterna entre activa y desactivada
}

## Ruta al nodo LevelPortal a modificar (relativo al trigger o ruta absoluta)
@export var target_door_path: NodePath

## Operación a realizar sobre la puerta
@export var operation: DoorOperation = DoorOperation.UNLOCK

func get_action_name() -> String:
	return "DoorAction (%s -> %s)" % [str(target_door_path), DoorOperation.keys()[operation]]

func execute(trigger_node: Node) -> void:
	if target_door_path.is_empty():
		push_warning("DoorAction: target_door_path está vacío.")
		finished.emit()
		return

	var target: Node = trigger_node.get_node_or_null(target_door_path)
	if not target:
		push_warning("DoorAction: No se encontró la puerta en la ruta: %s" % str(target_door_path))
		finished.emit()
		return

	var portal: LevelPortal = target as LevelPortal
	if portal == null:
		push_warning("DoorAction: El nodo objetivo '%s' no es un LevelPortal." % target.name)
		finished.emit()
		return

	match operation:
		DoorOperation.UNLOCK:
			portal.unlock()
		DoorOperation.LOCK:
			portal.lock()
		DoorOperation.ACTIVATE:
			portal.set_active_state(true)
		DoorOperation.DEACTIVATE:
			portal.set_active_state(false)
		DoorOperation.TOGGLE_LOCK:
			if portal.is_locked:
				portal.unlock()
			else:
				portal.lock()
		DoorOperation.TOGGLE_ACTIVE:
			portal.set_active_state(not portal.is_active)

	print("[DoorAction]: Operación %s ejecutada sobre '%s'" % [DoorOperation.keys()[operation], portal.name])
	finished.emit()
