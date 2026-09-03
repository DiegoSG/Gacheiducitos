extends Node2D

@onready var status_label: Label = $UI/StatusLabel
@onready var info_label: Label = $UI/InfoLabel

func _ready() -> void:
	if GameManager:
		GameManager.alert_state_changed.connect(_on_alert_state_changed)
		_update_ui(GameManager.alert_state)

func _on_alert_state_changed(new_state: GameManager.WorldAlertState) -> void:
	_update_ui(new_state)

func _update_ui(state: GameManager.WorldAlertState) -> void:
	if not is_instance_valid(status_label):
		return
		
	if state == GameManager.WorldAlertState.ALERT:
		status_label.text = "ESTADO: ALERTA (Persecución Activa)"
		status_label.modulate = Color.RED
		info_label.text = "¡Un enemigo te persigue! La interacción con NPCs está bloqueada."
	else:
		status_label.text = "ESTADO: PAZ"
		status_label.modulate = Color.GREEN
		info_label.text = "En paz. Puedes presionar [Espacio/Enter] frente a Barnaby para hablar."
