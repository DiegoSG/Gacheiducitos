extends Control

@onready var win_condition_option = $VBoxContainer/WinCondition/OptionButton
@onready var target_value_container = $VBoxContainer/TargetValue
@onready var target_value_slider = $VBoxContainer/TargetValue/Slider
@onready var target_value_label = $VBoxContainer/TargetValue/Value
@onready var target_label = $VBoxContainer/TargetValue/Label
@onready var speed_slider = $VBoxContainer/Speed/Slider
@onready var speed_label = $VBoxContainer/Speed/Value
@onready var density_slider = $VBoxContainer/Density/Slider
@onready var density_label = $VBoxContainer/Density/Value
@onready var dist_factor_slider = $VBoxContainer/DistanceFactor/Slider
@onready var dist_factor_label = $VBoxContainer/DistanceFactor/Value
@onready var start_button = $VBoxContainer/StartButton
@onready var exit_button = $VBoxContainer/ExitButton

var config = {
	"win_condition": 0, # 0: Distancia, 1: Obstáculos, 2: Monedas
	"target_value": 1500,
	"run_speed": 350,
	"coin_density": 0.4,
	"distance_factor": 0.1
}

func _ready():
	win_condition_option.item_selected.connect(_on_win_condition_selected)
	target_value_slider.value_changed.connect(_on_target_value_changed)
	speed_slider.value_changed.connect(_on_speed_changed)
	density_slider.value_changed.connect(_on_density_changed)
	dist_factor_slider.value_changed.connect(_on_dist_factor_changed)
	start_button.pressed.connect(_on_start_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	
	_update_ui()

func _update_ui():
	match config.win_condition:
		0: # Distancia
			target_label.text = "Distancia Objetivo:"
			target_value_slider.min_value = 500
			target_value_slider.max_value = 5000
			target_value_slider.step = 100
		1: # Obstáculos
			target_label.text = "Líneas de Obstáculos:"
			target_value_slider.min_value = 5
			target_value_slider.max_value = 100
			target_value_slider.step = 5
		2: # Monedas
			target_label.text = "Monedas a Recolectar:"
			target_value_slider.min_value = 5
			target_value_slider.max_value = 100
			target_value_slider.step = 5
			
	target_value_slider.set_value_no_signal(config.target_value)
	target_value_label.text = str(config.target_value)
	speed_slider.set_value_no_signal(config.run_speed)
	speed_label.text = str(config.run_speed)
	density_slider.set_value_no_signal(config.coin_density)
	density_label.text = "%.2f" % config.coin_density
	dist_factor_slider.set_value_no_signal(config.distance_factor)
	dist_factor_label.text = "%.2f" % config.distance_factor

func _on_win_condition_selected(index: int):
	config.win_condition = index
	if index == 0: config.target_value = 1500
	elif index == 1: config.target_value = 25
	elif index == 2: config.target_value = 20
	_update_ui()

func _on_target_value_changed(value: float):
	config.target_value = int(value)
	target_value_label.text = str(config.target_value)

func _on_speed_changed(value: float):
	config.run_speed = int(value)
	speed_label.text = str(config.run_speed)

func _on_density_changed(value: float):
	config.coin_density = value
	density_label.text = "%.2f" % config.coin_density

func _on_dist_factor_changed(value: float):
	config.distance_factor = value
	dist_factor_label.text = "%.2f" % config.distance_factor

func _on_start_pressed():
	GameManager.minigame_config = config
	GameManager.load_minigame("res://src/minigames/mg_runner/mg_runner_level.tscn", Vector2.ZERO)

func _on_exit_pressed():
	GameManager.return_to_overworld()
