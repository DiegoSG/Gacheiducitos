class_name PauseMenu
extends CanvasLayer

## Pause menu. Requests/releases the pause from GameManager (safe counting) and closes on its own.
## Usage: var m: PauseMenu = preload("res://src/ui/menus/pause_menu.tscn").instantiate()
## m.mode = PauseMenu.Mode.MINIGAME (optional); add_child(m); connect closed / abandon_requested.
## Closes with Resume, `pause` or ui_cancel. The pause is released BEFORE the signals are emitted.

signal closed
## Only in MINIGAME mode: the player gives up (counts as a loss).
signal abandon_requested

enum Mode { OVERWORLD, MINIGAME }

const OPTIONS_SCENE: PackedScene = preload("res://src/ui/menus/options_menu.tscn")
const SAVE_MENU_SCENE: PackedScene = preload("res://src/ui/save/save_menu_ui.tscn")
const START_MENU_PATH: String = "res://src/ui/menus/start_menu.tscn"

var mode: Mode = Mode.OVERWORLD

@onready var _menu: MenuBase = $MenuBase
@onready var _overlay: Control = $Overlay

var _pause_held: bool = false
var _sub: Control = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.request_pause()
	_pause_held = true
	_menu.set_title("Pausa")
	_menu.add_item("Reanudar", _close)
	if mode == Mode.OVERWORLD:
		_menu.add_item("Guardar", _open_save)
	_menu.add_item("Opciones", _open_options)
	if mode == Mode.OVERWORLD:
		_menu.add_item("Salir al menú de inicio", _exit_to_start)
	else:
		_menu.add_item("Abandonar minijuego", _abandon)
	_menu.back_requested.connect(_close)
	_menu.focus_first()

func _exit_tree() -> void:
	_release_pause()

func _release_pause() -> void:
	if _pause_held:
		_pause_held = false
		GameManager.release_pause()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if _sub == null:
			_close()
		else:
			_close_sub()

func _close() -> void:
	AudioManager.play_ui(&"sfx_ui_pause_close")
	_release_pause()
	closed.emit()
	queue_free()

func _abandon() -> void:
	AudioManager.play_ui(&"sfx_ui_abandon")
	_release_pause()
	abandon_requested.emit()
	closed.emit()
	queue_free()

func _exit_to_start() -> void:
	AudioManager.play_ui(&"sfx_ui_exit_to_start")
	_menu.hide()
	_pause_held = false # change_level resets the pause count
	GameManager.change_level(START_MENU_PATH)

func _open_options() -> void:
	var options: OptionsMenu = OPTIONS_SCENE.instantiate() as OptionsMenu
	options.closed.connect(_close_sub)
	_show_sub(options)

func _open_save() -> void:
	var save_ui: Control = SAVE_MENU_SCENE.instantiate() as Control
	var wrapper: Control = Control.new()
	wrapper.set_anchors_preset(Control.PRESET_FULL_RECT)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrapper.add_child(center)
	center.add_child(save_ui)
	_show_sub(wrapper)
	# First visible and enabled button (the autosave's "Guardar" is hidden and cannot take focus).
	save_ui.call("focus_first")

func _show_sub(sub: Control) -> void:
	_sub = sub
	AudioManager.play_ui(&"sfx_ui_submenu_open")
	_menu.hide()
	_overlay.add_child(sub)

func _close_sub() -> void:
	if _sub == null:
		return
	_sub.queue_free()
	_sub = null
	AudioManager.play_ui(&"sfx_ui_submenu_close")
	_menu.show()
	_menu.focus_first()

func _input(event: InputEvent) -> void:
	# ui_cancel inside a submenu without its own MenuBase (save) returns to the pause menu.
	if _sub != null and event.is_action_pressed("ui_cancel") and not (_sub is OptionsMenu):
		get_viewport().set_input_as_handled()
		_close_sub()
