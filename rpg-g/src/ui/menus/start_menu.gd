class_name StartMenu
extends Control

## Menú de inicio (escena principal). Jugar / Continuar / Opciones / Salir.
## Uso: se configura como run/main_scene (res://src/ui/menus/start_menu.tscn).

const NEW_GAME_LEVEL: String = "res://src/overworld/levels/level_01.tscn"
const OPTIONS_SCENE: PackedScene = preload("res://src/ui/menus/options_menu.tscn")

@onready var _menu: MenuBase = $MenuBase

var _options: OptionsMenu = null

func _ready() -> void:
	# GameManager libera current_scene al cambiar de nivel; en la escena principal apunta a otro nodo.
	GameManager.current_scene = self
	_menu.set_title("RPG-G")
	_build_items()
	_menu.focus_first()

func _build_items() -> void:
	# Continuar carga siempre el autoguardado; las partidas manuales se cargan desde Pausa > Guardar.
	var autosave_meta: Dictionary = SaveSystem.get_slot_metadata(SaveSystem.AUTOSAVE_SLOT_ID)
	if autosave_meta.get("exists", false):
		_menu.add_item("Continuar", _on_continue_pressed)
	_menu.add_item("Jugar", _on_play_pressed)
	_menu.add_item("Opciones", _on_options_pressed)
	_menu.add_item("Salir", _on_quit_pressed)

func _on_continue_pressed() -> void:
	AudioManager.play_ui(&"sfx_ui_continue")
	SaveSystem.load_slot(SaveSystem.AUTOSAVE_SLOT_ID)

func _on_play_pressed() -> void:
	AudioManager.play_ui(&"sfx_ui_new_game")
	GameManager.change_level(NEW_GAME_LEVEL)

func _on_options_pressed() -> void:
	AudioManager.play_ui(&"sfx_ui_options_open")
	_options = OPTIONS_SCENE.instantiate() as OptionsMenu
	add_child(_options)
	_options.closed.connect(_on_options_closed)
	_menu.hide()

func _on_options_closed() -> void:
	_options.queue_free()
	_options = null
	_menu.show()
	_menu.focus_first()

func _on_quit_pressed() -> void:
	AudioManager.play_ui(&"sfx_ui_quit")
	get_tree().quit()
