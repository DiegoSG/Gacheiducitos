extends Control

# Referencias a los sliders y labels
@onready var initial_speed_slider = $VBoxContainer/InitialSpeed/Slider
@onready var initial_speed_label = $VBoxContainer/InitialSpeed/Value
@onready var final_speed_slider = $VBoxContainer/FinalSpeed/Slider
@onready var final_speed_label = $VBoxContainer/FinalSpeed/Value
@onready var spawn_points_slider = $VBoxContainer/SpawnPoints/Slider
@onready var spawn_points_label = $VBoxContainer/SpawnPoints/Value
@onready var bugs_per_spawn_slider = $VBoxContainer/BugsPerSpawn/Slider
@onready var bugs_per_spawn_label = $VBoxContainer/BugsPerSpawn/Value
@onready var game_mode_option = $VBoxContainer/GameMode/OptionButton
@onready var target_value_slider = $VBoxContainer/TargetValue/Slider
@onready var target_value_label = $VBoxContainer/TargetValue/Value
@onready var lives_slider = $VBoxContainer/Lives/Slider
@onready var lives_label = $VBoxContainer/Lives/Value

@onready var start_button = $VBoxContainer/StartButton
@onready var exit_button = $VBoxContainer/ExitButton

# Parámetros de configuración
var config = {
	"initial_speed": 100.0,
	"final_speed": 400.0,
	"num_spawn_points": 8,
	"bugs_per_spawn": 1,
	"game_mode": "TIME",
	"target_value": 30.0,
	"lives": 3
}

func _ready():
	# Configurar valores iniciales
	initial_speed_slider.value = config.initial_speed
	final_speed_slider.value = config.final_speed
	spawn_points_slider.value = config.num_spawn_points
	bugs_per_spawn_slider.value = config.bugs_per_spawn
	game_mode_option.selected = 0 if config.game_mode == "TIME" else 1
	target_value_slider.value = config.target_value
	lives_slider.value = config.lives
	
	# Conectar señales
	initial_speed_slider.value_changed.connect(_on_initial_speed_changed)
	final_speed_slider.value_changed.connect(_on_final_speed_changed)
	spawn_points_slider.value_changed.connect(_on_spawn_points_changed)
	bugs_per_spawn_slider.value_changed.connect(_on_bugs_per_spawn_changed)
	game_mode_option.item_selected.connect(_on_game_mode_selected)
	target_value_slider.value_changed.connect(_on_target_value_changed)
	lives_slider.value_changed.connect(_on_lives_changed)
	
	start_button.pressed.connect(_on_start_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	
	_update_labels()

func _update_labels():
	initial_speed_label.text = str(config.initial_speed)
	final_speed_label.text = str(config.final_speed)
	spawn_points_label.text = str(config.num_spawn_points)
	bugs_per_spawn_label.text = str(config.bugs_per_spawn)
	target_value_label.text = str(config.target_value)
	lives_label.text = str(config.lives)

func _on_initial_speed_changed(value: float):
	config.initial_speed = value
	_update_labels()

func _on_final_speed_changed(value: float):
	config.final_speed = value
	_update_labels()

func _on_spawn_points_changed(value: float):
	config.num_spawn_points = int(value)
	_update_labels()

func _on_bugs_per_spawn_changed(value: float):
	config.bugs_per_spawn = int(value)
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
	GameManager.load_minigame("res://src/minigames/mg_smasher/mg_smasher_game.tscn", Vector2.ZERO)

func _on_exit_pressed():
	GameManager.return_to_overworld()
