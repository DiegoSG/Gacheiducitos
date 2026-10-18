class_name PauseController
extends Node

## Listens for the `pause` action and opens/closes the Overworld pause menu.
## Usage: instantiate res://src/ui/menus/pause_controller.tscn (e.g. as a child of the PlayerHUD).
## Does not open the menu if the game is already paused by another system (dialogue, inventory...).

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
