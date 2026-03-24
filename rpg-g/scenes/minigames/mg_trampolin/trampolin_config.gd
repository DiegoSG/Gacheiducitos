extends Control

@onready var win_condition_option = $VBoxContainer/WinCondition/OptionButton
@onready var target_value_container = $VBoxContainer/TargetValue
@onready var target_value_slider = $VBoxContainer/TargetValue/Slider
@onready var target_value_label = $VBoxContainer/TargetValue/Value
@onready var target_label = $VBoxContainer/TargetValue/Label
@onready var coin_density_slider = $VBoxContainer/CoinDensity/Slider
@onready var coin_density_label = $VBoxContainer/CoinDensity/Value
@onready var special_height_slider = $VBoxContainer/SpecialHeight/Slider
@onready var special_height_label = $VBoxContainer/SpecialHeight/Value
@onready var start_button = $VBoxContainer/StartButton
@onready var exit_button = $VBoxContainer/ExitButton

var config = {
	"win_condition": 0, # 0: Altura, 1: Trampolín Especial, 2: Monedas
	"target_value": 100,
	"coin_density": 0.3,
	"special_height": 300
}

func _ready():
	# Conectar señales
	win_condition_option.item_selected.connect(_on_win_condition_selected)
	target_value_slider.value_changed.connect(_on_target_value_changed)
	coin_density_slider.value_changed.connect(_on_coin_density_changed)
	special_height_slider.value_changed.connect(_on_special_height_changed)
	start_button.pressed.connect(_on_start_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	
	_update_ui()

func _update_ui():
	match config.win_condition:
		0: # Altura
			target_label.text = "Altura Objetivo:"
			target_value_slider.min_value = 50
			target_value_slider.max_value = 500
			target_value_slider.step = 10
			target_value_container.visible = true
		1: # Especial
			target_value_container.visible = false
		2: # Monedas
			target_label.text = "Num. Monedas:"
			target_value_slider.min_value = 5
			target_value_slider.max_value = 50
			target_value_slider.step = 1
			target_value_container.visible = true
	
	target_value_label.text = str(config.target_value)
	coin_density_label.text = "%.1f" % config.coin_density
	special_height_label.text = str(config.special_height)

func _on_win_condition_selected(index: int):
	config.win_condition = index
	if index == 0: config.target_value = 100
	elif index == 2: config.target_value = 10
	_update_ui()

func _on_target_value_changed(value: float):
	config.target_value = int(value)
	target_value_label.text = str(config.target_value)

func _on_coin_density_changed(value: float):
	config.coin_density = value
	coin_density_label.text = "%.1f" % value

func _on_special_height_changed(value: float):
	config.special_height = int(value)
	special_height_label.text = str(config.special_height)

func _on_start_pressed():
	GameManager.minigame_config = config
	GameManager.load_minigame("res://scenes/minigames/mg_trampolin/mg_trampolin.tscn", Vector2.ZERO)

func _on_exit_pressed():
	GameManager.return_to_overworld()
