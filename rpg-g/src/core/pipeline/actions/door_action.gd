class_name DoorAction
extends ActionResource

## Modifica el estado de un LevelPortal o Puerta en el mapa (abrir, cerrar, bloquear, desbloquear, activar, desactivar).

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
		
	var door_node: Node = trigger_node.get_node_or_null(target_door_path)
	if not door_node:
		push_warning("DoorAction: No se encontró la puerta en la ruta: %s" % str(target_door_path))
		finished.emit()
		return
		
	if not (door_node is LevelPortal):
		# Intento de fallback si el script tiene los métodos correspondientes
		if not door_node.has_method("unlock") and not ("is_locked" in door_node):
			push_warning("DoorAction: El nodo objetivo '%s' no es un LevelPortal." % door_node.name)
			finished.emit()
			return

	match operation:
		DoorOperation.UNLOCK:
			if door_node.has_method("unlock"):
				door_node.unlock()
			elif "is_locked" in door_node:
				door_node.is_locked = false
		DoorOperation.LOCK:
			if door_node.has_method("lock"):
				door_node.lock()
			elif "is_locked" in door_node:
				door_node.is_locked = true
		DoorOperation.ACTIVATE:
			if door_node.has_method("set_active_state"):
				door_node.set_active_state(true)
			elif "is_active" in door_node:
				door_node.is_active = true
		DoorOperation.DEACTIVATE:
			if door_node.has_method("set_active_state"):
				door_node.set_active_state(false)
			elif "is_active" in door_node:
				door_node.is_active = false
		DoorOperation.TOGGLE_LOCK:
			if "is_locked" in door_node:
				if door_node.is_locked:
					if door_node.has_method("unlock"):
						door_node.unlock()
					else:
						door_node.is_locked = false
				else:
					if door_node.has_method("lock"):
						door_node.lock()
					else:
						door_node.is_locked = true
		DoorOperation.TOGGLE_ACTIVE:
			if "is_active" in door_node:
				var new_state = not door_node.is_active
				if door_node.has_method("set_active_state"):
					door_node.set_active_state(new_state)
				else:
					door_node.is_active = new_state

	print("[DoorAction]: Operación %s ejecutada sobre '%s'" % [DoorOperation.keys()[operation], door_node.name])
	finished.emit()
