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
	"win_condition": 0, # 0: Distancia, 1: Objeto
	"target_value": 1500,
	"target_item_id": "ancient_map",
	"target_distance_range": Vector2(800.0, 1400.0),
	"run_speed": 380,
	"coin_density": 0.55,
	"distance_factor": 0.10,
	"item_pool": ["blue_potion", "red_potion", "green_herb"]
}

func _ready():
	win_condition_option.item_selected.connect(_on_win_condition_selected)
	target_value_slider.value_changed.connect(_on_target_value_changed)
	speed_slider.value_changed.connect(_on_speed_changed)
	density_slider.value_changed.connect(_on_density_changed)
	dist_factor_slider.value_changed.connect(_on_dist_factor_changed)
	start_button.pressed.connect(_on_start_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	
	_setup_options()
	_update_ui()

func _setup_options():
	win_condition_option.clear()
	win_condition_option.add_item("Por Distancia (Metros)", 0)
	win_condition_option.add_item("Por Objeto Clave (Meta)", 1)
	win_condition_option.select(config.win_condition)

func _update_ui():
	match config.win_condition:
		0: # Distancia
			target_label.text = "Distancia Meta:"
			target_value_slider.min_value = 500
			target_value_slider.max_value = 5000
			target_value_slider.step = 100
			target_value_slider.set_value_no_signal(config.target_value)
			target_value_label.text = "%d m" % config.target_value
		1: # Objeto
			target_label.text = "Distancia Objeto:"
			target_value_slider.min_value = 400
			target_value_slider.max_value = 3000
			target_value_slider.step = 100
			target_value_slider.set_value_no_signal(config.target_distance_range.x)
			target_value_label.text = "~%d m" % int(config.target_distance_range.x)
			
	speed_slider.set_value_no_signal(config.run_speed)
	speed_label.text = str(config.run_speed)
	density_slider.set_value_no_signal(config.coin_density)
	density_label.text = "%.2f" % config.coin_density
	dist_factor_slider.set_value_no_signal(config.distance_factor)
	dist_factor_label.text = "%.2f" % config.distance_factor

func _on_win_condition_selected(index: int):
	config.win_condition = index
	if index == 0:
		config.target_value = 1500
	elif index == 1:
		config.target_item_id = "ancient_map"
		config.target_distance_range = Vector2(800.0, 1200.0)
	_update_ui()

func _on_target_value_changed(value: float):
	if config.win_condition == 0:
		config.target_value = int(value)
		target_value_label.text = "%d m" % config.target_value
	else:
		config.target_distance_range = Vector2(value, value + 400.0)
		target_value_label.text = "~%d m" % int(value)

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
	GameManager.load_minigame("res://src/minigames/mg_runner/mg_runner_level.tscn")

func _on_exit_pressed():
	GameManager.return_to_overworld()
