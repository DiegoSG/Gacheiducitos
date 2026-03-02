extends Control

# Referencias a los sliders y labels
@onready var densidad_tierra_slider = $VBoxContainer/DensidadTierra/Slider
@onready var densidad_tierra_label = $VBoxContainer/DensidadTierra/Value
@onready var prob_piedra_slider = $VBoxContainer/ProbPiedra/Slider
@onready var prob_piedra_label = $VBoxContainer/ProbPiedra/Value
@onready var num_enemigos_slider = $VBoxContainer/NumEnemigos/Slider
@onready var num_enemigos_label = $VBoxContainer/NumEnemigos/Value
@onready var tiempo_limite_slider = $VBoxContainer/TiempoLimite/Slider
@onready var tiempo_limite_label = $VBoxContainer/TiempoLimite/Value
@onready var seed_input = $VBoxContainer/Seed/LineEdit
@onready var start_button = $VBoxContainer/StartButton
@onready var exit_button = $VBoxContainer/ExitButton
@onready var escala_slider = $VBoxContainer/Escala/Slider
@onready var escala_label = $VBoxContainer/Escala/Value

# Parámetros de configuración
var config = {
	"densidad_tierra": 0.45,
	"probabilidad_piedra": 0.15,
	"num_enemigos": 3,
	"tiempo_limite": 180,
	"seed": -1,
	"show_player_logic": false,
	"show_rock_logic": false,
	"escala": 1.5
}

@onready var player_logic_check = $VBoxContainer/VisibilidadDebug/PlayerLogic
@onready var rock_logic_check = $VBoxContainer/VisibilidadDebug/RockLogic

func _ready():
	# Configurar valores iniciales
	densidad_tierra_slider.value = config.densidad_tierra
	prob_piedra_slider.value = config.probabilidad_piedra
	num_enemigos_slider.value = config.num_enemigos
	tiempo_limite_slider.value = config.tiempo_limite
	player_logic_check.button_pressed = config.show_player_logic
	rock_logic_check.button_pressed = config.show_rock_logic
	escala_slider.value = config.escala
	
	# Conectar señales
	densidad_tierra_slider.value_changed.connect(_on_densidad_tierra_changed)
	prob_piedra_slider.value_changed.connect(_on_prob_piedra_changed)
	num_enemigos_slider.value_changed.connect(_on_num_enemigos_changed)
	tiempo_limite_slider.value_changed.connect(_on_tiempo_limite_changed)
	escala_slider.value_changed.connect(_on_escala_changed)
	player_logic_check.toggled.connect(_on_player_logic_toggled)
	rock_logic_check.toggled.connect(_on_rock_logic_toggled)
	start_button.pressed.connect(_on_start_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	
	# Actualizar labels
	_update_labels()

func _update_labels():
	densidad_tierra_label.text = "%.2f" % config.densidad_tierra
	prob_piedra_label.text = "%.2f" % config.probabilidad_piedra
	num_enemigos_label.text = str(config.num_enemigos)
	tiempo_limite_label.text = "%d:%02d" % [config.tiempo_limite / 60, config.tiempo_limite % 60]
	escala_label.text = "%.1fx" % config.escala

func _on_densidad_tierra_changed(value: float):
	config.densidad_tierra = value
	_update_labels()

func _on_prob_piedra_changed(value: float):
	config.probabilidad_piedra = value
	_update_labels()

func _on_num_enemigos_changed(value: float):
	config.num_enemigos = int(value)
	_update_labels()

func _on_tiempo_limite_changed(value: float):
	config.tiempo_limite = int(value)
	_update_labels()

func _on_escala_changed(value: float):
	config.escala = value
	_update_labels()

func _on_player_logic_toggled(button_pressed: bool):
	config.show_player_logic = button_pressed

func _on_rock_logic_toggled(button_pressed: bool):
	config.show_rock_logic = button_pressed

func _on_start_pressed():
	# Obtener seed del input
	var seed_text = seed_input.text.strip_edges()
	if seed_text.is_empty():
		config.seed = -1  # Seed aleatorio
	else:
		config.seed = int(seed_text)
	
	# Pasar configuración al GameManager
	GameManager.minigame_config = config
	
	# Cargar el minijuego
	GameManager.load_minigame("res://scenes/minigames/mg_excavation/mg_excavation_game.tscn", Vector2.ZERO)

func _on_exit_pressed():
	print("DebugConfig: Exit button pressed")
	# Volver al overworld
	if GameManager.previous_scene_path == "":
		print("DebugConfig: WARNING - previous_scene_path is empty!")
	else:
		print("DebugConfig: Returning to: ", GameManager.previous_scene_path)
	GameManager.return_to_overworld()
