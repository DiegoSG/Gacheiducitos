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
	_button_list.add_child(button)
	return button

func clear_items() -> void:
	for child: Node in _button_list.get_children():
		_button_list.remove_child(child)
		child.queue_free()

## Da el foco al primer botón habilitado.
func focus_first() -> void:
	for child: Node in _button_list.get_children():
		var button: Button = child as Button
		if button != null and not button.disabled:
			button.grab_focus()
			return

func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_requested.emit()
