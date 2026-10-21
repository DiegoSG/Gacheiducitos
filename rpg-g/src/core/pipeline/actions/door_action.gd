class_name DoorAction
extends ActionResource

## Changes the state of a LevelPortal on the map (lock, unlock, activate, deactivate).

enum DoorOperation {
	UNLOCK,          ## Unlocks the door (removes the lock)
	LOCK,            ## Locks the door with a lock
	ACTIVATE,        ## Enables the portal/door
	DEACTIVATE,      ## Disables the portal/door
	TOGGLE_LOCK,     ## Toggles between locked and unlocked
	TOGGLE_ACTIVE    ## Toggles between active and inactive
}

## Path to the LevelPortal node to modify (relative to the trigger or an absolute path)
@export var target_door_path: NodePath

## Operation to perform on the door
@export var operation: DoorOperation = DoorOperation.UNLOCK

func get_action_name() -> String:
	return "DoorAction (%s -> %s)" % [str(target_door_path), DoorOperation.keys()[operation]]

func execute(trigger_node: Node) -> void:
	if target_door_path.is_empty():
		push_warning("DoorAction: target_door_path is empty.")
		finished.emit()
		return

	var target: Node = trigger_node.get_node_or_null(target_door_path)
	if not target:
		push_warning("DoorAction: Door not found at path: %s" % str(target_door_path))
		finished.emit()
		return

	var portal: LevelPortal = target as LevelPortal
	if portal == null:
		push_warning("DoorAction: The target node '%s' is not a LevelPortal." % target.name)
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

	finished.emit()
