class_name LootToastItem
extends PanelContainer

## Componente visual individual para la notificación de loot al lado del inventario.
## Muestra icono, nombre y cantidad apilada ('x N'), permaneciendo visible un tiempo
## y desvaneciéndose suavemente antes de eliminarse.

@onready var margin_container: MarginContainer = $MarginContainer
@onready var hbox: HBoxContainer = $MarginContainer/HBoxContainer
@onready var icon_rect: TextureRect = $MarginContainer/HBoxContainer/IconRect
@onready var name_label: Label = $MarginContainer/HBoxContainer/NameLabel
@onready var count_label: Label = $MarginContainer/HBoxContainer/CountLabel

var item_id: String = ""
var current_amount: int = 1
var remaining_time: float = 2.5
const DISPLAY_DURATION: float = 2.5
const FADE_DURATION: float = 0.4

var _is_fading: bool = false
var _fade_tween: Tween = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_END
	resized.connect(_on_resized)
	_update_pivot()

func _on_resized() -> void:
	_update_pivot()

func _update_pivot() -> void:
	pivot_offset = size * 0.5

## Configura los datos iniciales del ítem y ejecuta una pequeña animación de entrada
func setup(item_data: ItemData, amount: int = 1) -> void:
	if not item_data:
		return
		
	item_id = item_data.id
	current_amount = amount
	remaining_time = DISPLAY_DURATION
	_is_fading = false
	
	if icon_rect and item_data.icon:
		icon_rect.texture = item_data.icon
	if name_label:
		name_label.text = item_data.name if not item_data.name.is_empty() else item_id.capitalize().replace("_", " ")
	if count_label:
		_update_count_label()
		
	# Animación de aparición (scale pop & fade in)
	scale = Vector2(0.85, 0.85)
	modulate.a = 0.0

	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.10)

## Añade cantidad acumulativa ('x N'), reinicia el temporizador y hace un punch de escala
func add_amount(amount: int) -> void:
	current_amount += amount
	remaining_time = DISPLAY_DURATION
	_update_count_label()
	
	# Cancelar desvanecimiento si estaba en proceso
	if _is_fading:
		if _fade_tween and _fade_tween.is_valid():
			_fade_tween.kill()
		modulate.a = 1.0
		_is_fading = false
		
	# Punch de escala para refuerzo visual
	var tw: Tween = create_tween()
	tw.tween_property(self, "scale", Vector2(1.22, 1.22), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _update_count_label() -> void:
	if count_label:
		count_label.text = "x %d" % current_amount
		count_label.visible = true

func _process(delta: float) -> void:
	if _is_fading:
		return
		
	remaining_time -= delta
	if remaining_time <= FADE_DURATION:
		_start_fade_out()

func _start_fade_out() -> void:
	_is_fading = true
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_fade_tween.tween_callback(queue_free)
