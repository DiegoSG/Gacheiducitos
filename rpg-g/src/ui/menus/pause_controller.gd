class_name PauseController
extends Node

## Escucha la acción `pause` y abre/cierra el menú de pausa del Overworld.
## Uso: instanciar res://src/ui/menus/pause_controller.tscn (p. ej. hijo del PlayerHUD).
## No abre el menú si el juego ya está pausado por otro sistema (diálogo, inventario...).

const PAUSE_MENU_SCENE: PackedScene = preload("res://src/ui/menus/pause_menu.tscn")

var _menu: PauseMenu = null

func _unhandled_input(event: InputEvent) -> void:
	if _menu != null or get_tree().paused:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		AudioManager.play_ui(&"sfx_ui_pause_open")
		_menu = PAUSE_MENU_SCENE.instantiate() as PauseMenu
		_menu.closed.connect(_on_menu_closed)
		add_child(_menu)

func _on_menu_closed() -> void:
	_menu = null
