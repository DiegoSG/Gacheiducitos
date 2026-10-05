extends Node

enum WorldAlertState {
	PEACE,
	ALERT
}

signal alert_state_changed(new_state: WorldAlertState)

var alert_state: WorldAlertState = WorldAlertState.PEACE
var _active_pursuers: Array[Node] = []

func _process(_delta: float) -> void:
	_cleanup_invalid_pursuers()

func register_pursuer(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return
	if not _active_pursuers.has(enemy):
		_active_pursuers.append(enemy)
	_update_alert_state()

func unregister_pursuer(enemy: Node) -> void:
	if _active_pursuers.has(enemy):
		_active_pursuers.erase(enemy)
	_update_alert_state()

func is_in_alert() -> bool:
	return alert_state == WorldAlertState.ALERT

func clear_pursuers() -> void:
	_active_pursuers.clear()
	_update_alert_state()

func _cleanup_invalid_pursuers() -> void:
	_active_pursuers = _active_pursuers.filter(func(node: Node) -> bool: return is_instance_valid(node) and node.is_inside_tree())

func _update_alert_state() -> void:
	_cleanup_invalid_pursuers()
	var new_state: WorldAlertState = WorldAlertState.ALERT if _active_pursuers.size() > 0 else WorldAlertState.PEACE
	if new_state != alert_state:
		alert_state = new_state
		AudioManager.play_sfx(&"sfx_alert_on" if new_state == WorldAlertState.ALERT else &"sfx_alert_off")
		alert_state_changed.emit(alert_state)
