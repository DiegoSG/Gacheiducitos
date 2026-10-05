class_name MenuBase
extends Control

## Menú base reutilizable: título + lista vertical de botones.
## Navegación con ui_up/ui_down (nativa de Control), Confirmar = ui_accept (nativo del Button),
## Atrás = ui_cancel (emite back_requested). Lo usan inicio, pausa y opciones.
## Uso: instanciar menu_base.tscn, llamar add_item() y conectar back_requested.

signal back_requested

@export var title: String = ""

@onready var _title_label: Label = %TitleLabel
@onready var _button_list: VBoxContainer = %ButtonList

## Evita el sonido de foco cuando el foco inicial lo pone focus_first()
var _silence_focus_sound: bool = false

func _ready() -> void:
	_title_label.text = title
	_title_label.visible = not title.is_empty()

func set_title(new_title: String) -> void:
	title = new_title
	if is_node_ready():
		_title_label.text = new_title
		_title_label.visible = not new_title.is_empty()

## Añade un botón a la lista. Una fila deshabilitada no recibe foco.
func add_item(text: String, action: Callable = Callable(), disabled: bool = false) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.disabled = disabled
	button.custom_minimum_size = Vector2(240, 40)
	if action.is_valid():
		button.pressed.connect(action)
	button.pressed.connect(_on_button_pressed)
	button.focus_entered.connect(_on_focus_entered)
	if disabled:
		button.gui_input.connect(_on_disabled_button_gui_input)
	_button_list.add_child(button)
	return button

## Añade una fila con etiqueta y slider (0.0 a 1.0). Izquierda/derecha cambian el valor.
func add_slider(text: String, value: float, on_changed: Callable) -> HSlider:
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(240, 40)
	var label: Label = Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(100, 0)
	var slider: HSlider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_ALL
	slider.focus_entered.connect(_on_focus_entered)
	if on_changed.is_valid():
		slider.value_changed.connect(on_changed)
	row.add_child(label)
	row.add_child(slider)
	_button_list.add_child(row)
	return slider

func clear_items() -> void:
	for child: Node in _button_list.get_children():
		_button_list.remove_child(child)
		child.queue_free()

## Da el foco al primer botón habilitado o slider.
func focus_first() -> void:
	for child: Node in _button_list.get_children():
		var target: Control = _get_focus_target(child)
		if target != null:
			_silence_focus_sound = true
			target.grab_focus.call_deferred()
			_end_focus_silence.call_deferred()
			return

func _get_focus_target(child: Node) -> Control:
	var button: Button = child as Button
	if button != null:
		return null if button.disabled else button
	for grandchild: Node in child.get_children():
		if grandchild is Slider:
			return grandchild as Control
	return null

func _end_focus_silence() -> void:
	_silence_focus_sound = false

func _on_focus_entered() -> void:
	if not _silence_focus_sound:
		AudioManager.play_ui(&"sfx_ui_focus")

func _on_button_pressed() -> void:
	AudioManager.play_ui(&"sfx_ui_confirm")

func _on_disabled_button_gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		AudioManager.play_ui(&"sfx_ui_disabled")

func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		AudioManager.play_ui(&"sfx_ui_cancel")
		get_viewport().set_input_as_handled()
		back_requested.emit()
