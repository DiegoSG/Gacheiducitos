class_name OptionsMenu
extends Control

## Options menu. Opened from the start screen and pause.
## Usage: var m: OptionsMenu = preload("res://src/ui/menus/options_menu.tscn").instantiate()
## parent.add_child(m); m.closed.connect(...). Closes with Back or ui_cancel (emits closed;
## whoever opened it frees it with queue_free()). The volume is saved on close.

signal closed

@onready var _menu: MenuBase = $MenuBase

func _ready() -> void:
	_menu.set_title("Opciones")
	_menu.add_slider("Música", AudioManager.get_bus_volume(AudioManager.MUSIC_BUS), _on_music_volume_changed)
	_menu.add_slider("Efectos", AudioManager.get_bus_volume(AudioManager.SFX_BUS), _on_sfx_volume_changed)
	_menu.add_item("Controles", Callable(), true)
	_menu.add_item("Volver", _on_back)
	_menu.back_requested.connect(_on_back)
	_menu.focus_first()

func _on_music_volume_changed(value: float) -> void:
	AudioManager.set_bus_volume(AudioManager.MUSIC_BUS, value)

func _on_sfx_volume_changed(value: float) -> void:
	AudioManager.set_bus_volume(AudioManager.SFX_BUS, value)

func _on_back() -> void:
	AudioManager.save_settings()
	AudioManager.play_ui(&"sfx_ui_options_close")
	closed.emit()
