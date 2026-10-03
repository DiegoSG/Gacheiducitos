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
	if _has_autosave():
		_menu.add_item("Continuar", _on_continue_pressed)
	_menu.add_item("Jugar", _on_play_pressed)
	_menu.add_item("Opciones", _on_options_pressed)
	_menu.add_item("Salir", _on_quit_pressed)

## Continuar solo existe si hay autoguardado; las partidas manuales se cargan desde Pausa > Guardar.
func _has_autosave() -> bool:
	var metadatas: Array[Dictionary] = SaveSystem.get_all_slots_metadata()
	var id: int = SaveSystem.AUTOSAVE_SLOT_ID
	return id >= 0 and id < metadatas.size() and bool(metadatas[id].get("exists", false))

func _on_continue_pressed() -> void:
	SaveSystem.load_slot(SaveSystem.AUTOSAVE_SLOT_ID)

func _on_play_pressed() -> void:
	GameManager.change_level(NEW_GAME_LEVEL)

func _on_options_pressed() -> void:
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
	get_tree().quit()
