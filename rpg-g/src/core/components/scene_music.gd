class_name SceneMusic
extends Node

## Reproduce la música de la escena al entrar en ella. Se agrega como hijo de un nivel,
## minijuego o menú. Con music_id vacío, la escena queda en silencio.
## Si alert_music_id tiene valor, cambia a esa música mientras el mundo está en alerta.

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
