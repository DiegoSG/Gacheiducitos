extends CanvasLayer

@onready var health_label: Label = $MarginContainer/VBoxContainer/HBoxContainer_Health/HealthLabel
@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/HBoxContainer_Health/HealthBar
@onready var gold_label: Label = $MarginContainer/VBoxContainer/HBoxContainer_Gold/GoldLabel

func _ready() -> void:
	# Connect to PlayerStats signals
	if PlayerStats:
		PlayerStats.health_changed.connect(_on_health_changed)
		PlayerStats.gold_changed.connect(_on_gold_changed)
		
		# Initial update
		_on_health_changed(PlayerStats.health, PlayerStats.max_health)
		_on_gold_changed(PlayerStats.gold)

func _on_health_changed(current: int, max_val: int) -> void:
	health_label.text = "HP: %d/%d" % [current, max_val]
	health_bar.max_value = max_val
	health_bar.value = current

func _on_gold_changed(amount: int) -> void:
	gold_label.text = "Oro: %d" % amount
