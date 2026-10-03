class_name OptionsMenu
extends Control

## Menú de opciones (PLACEHOLDER, sin lógica). Se abre desde inicio y pausa.
## Uso: var m: OptionsMenu = preload("res://src/ui/menus/options_menu.tscn").instantiate()
## parent.add_child(m); m.closed.connect(...). Se cierra con Volver o ui_cancel (emite closed;
## quien lo abrió lo libera con queue_free()).

signal closed

@onready var _menu: MenuBase = $MenuBase

func _ready() -> void:
	_menu.set_title("Opciones")
	_menu.add_item("Volumen", Callable(), true)
	_menu.add_item("Controles", Callable(), true)
	_menu.add_item("Volver", _on_back)
	_menu.back_requested.connect(_on_back)
	_menu.focus_first()

func _on_back() -> void:
	closed.emit()
