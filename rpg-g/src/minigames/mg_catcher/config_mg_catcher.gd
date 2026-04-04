extends Control

# Referencias a los sliders y labels
@onready var fall_speed_slider = $VBoxContainer/FallSpeed/Slider
@onready var fall_speed_label = $VBoxContainer/FallSpeed/Value
@onready var spawn_rate_slider = $VBoxContainer/SpawnRate/Slider
@onready var spawn_rate_label = $VBoxContainer/SpawnRate/Value
@onready var max_objects_slider = $VBoxContainer/MaxObjects/Slider
@onready var max_objects_label = $VBoxContainer/MaxObjects/Value
@onready var game_mode_option = $VBoxContainer/GameMode/OptionButton
@onready var target_value_slider = $VBoxContainer/TargetValue/Slider
@onready var target_value_label = $VBoxContainer/TargetValue/Value
@onready var lives_slider = $VBoxContainer/Lives/Slider
@onready var lives_label = $VBoxContainer/Lives/Value

@onready var start_button = $VBoxContainer/StartButton
@onready var exit_button = $VBoxContainer/ExitButton

# Parámetros de configuración
var config = {
	"base_fall_speed": 200.0,
	"spawn_rate": 1.0,
	"max_falling_objects": 10,
	"game_mode": "TIME",
	"target_value": 30.0,
	"lives": 3
}

func _ready():
	# Configurar valores iniciales
	fall_speed_slider.value = config.base_fall_speed
	spawn_rate_slider.value = config.spawn_rate
	max_objects_slider.value = config.max_falling_objects
	game_mode_option.selected = 0 if config.game_mode == "TIME" else 1
	target_value_slider.value = config.target_value
	lives_slider.value = config.lives
	
	# Conectar señales
	fall_speed_slider.value_changed.connect(_on_fall_speed_changed)
	spawn_rate_slider.value_changed.connect(_on_spawn_rate_changed)
	max_objects_slider.value_changed.connect(_on_max_objects_changed)
	game_mode_option.item_selected.connect(_on_game_mode_selected)
	target_value_slider.value_changed.connect(_on_target_value_changed)
	lives_slider.value_changed.connect(_on_lives_changed)
	
	start_button.pressed.connect(_on_start_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	
	_update_labels()

func _update_labels():
	fall_speed_label.text = str(config.base_fall_speed)
	spawn_rate_label.text = "%.1f s" % config.spawn_rate
	max_objects_label.text = str(config.max_falling_objects)
	target_value_label.text = str(config.target_value)
	lives_label.text = str(config.lives)

func _on_fall_speed_changed(value: float):
	config.base_fall_speed = value
	_update_labels()

func _on_spawn_rate_changed(value: float):
	config.spawn_rate = value
	_update_labels()

func _on_max_objects_changed(value: float):
	config.max_falling_objects = int(value)
	_update_labels()

func _on_game_mode_selected(index: int):
	config.game_mode = "TIME" if index == 0 else "COUNT"
	_update_labels()

func _on_target_value_changed(value: float):
	config.target_value = value
	_update_labels()

func _on_lives_changed(value: float):
	config.lives = int(value)
	_update_labels()

func _on_start_pressed():
	GameManager.minigame_config = config
	GameManager.load_minigame("res://src/minigames/mg_catcher/mg_catcher_game.tscn", Vector2.ZERO)

func _on_exit_pressed():
	GameManager.return_to_overworld()
