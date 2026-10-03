class_name MapController
extends Node

## Escucha `map_toggle` y abre/cierra el MapMenu. Instanciar map_controller.tscn en el PlayerHUD.

const MAP_MENU_SCENE: PackedScene = preload("res://src/ui/map/map_menu.tscn")

var _menu: MapMenu = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("map_toggle"):
		return
	if is_instance_valid(_menu):
		close_map()
	elif not get_tree().paused and is_instance_valid(GameManager.current_scene):
		open_map()
	else:
		return
	get_viewport().set_input_as_handled()

func open_map() -> void:
	if is_instance_valid(_menu):
		return
	_menu = MAP_MENU_SCENE.instantiate() as MapMenu
	_menu.close_requested.connect(close_map)
	add_child(_menu)

func close_map() -> void:
	if is_instance_valid(_menu):
		_menu.queue_free()
	_menu = null
