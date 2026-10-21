class_name SceneMusic
extends Node

## Plays the scene's music when entering it. Added as a child of a level,
## minigame or menu. With music_id empty, the scene is silent.
## If alert_music_id has a value, switches to that music while the world is on alert.

@export var music_id: StringName = &""
@export var alert_music_id: StringName = &""
@export_range(0.0, 5.0, 0.1, "suffix:s") var fade_time: float = 0.5

func _ready() -> void:
	if not alert_music_id.is_empty():
		AlertSystem.alert_state_changed.connect(_on_alert_state_changed)
	_play_for_state(AlertSystem.alert_state)

func _on_alert_state_changed(new_state: AlertSystem.WorldAlertState) -> void:
	_play_for_state(new_state)

func _play_for_state(state: AlertSystem.WorldAlertState) -> void:
	var in_alert: bool = state == AlertSystem.WorldAlertState.ALERT
	if in_alert and not alert_music_id.is_empty():
		AudioManager.play_music(alert_music_id, fade_time)
	else:
		AudioManager.play_music(music_id, fade_time)
