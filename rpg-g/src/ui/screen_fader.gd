extends CanvasLayer
class_name ScreenFader

signal fade_out_completed
signal fade_in_completed

@onready var color_rect: ColorRect = $ColorRect
var _active_tween: Tween = null

func _ready() -> void:
	color_rect.modulate.a = 0.0
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func fade_out(duration: float = 0.4) -> void:
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	if _active_tween and _active_tween.is_running():
		_active_tween.kill()
	_active_tween = create_tween()
	_active_tween.tween_property(color_rect, "modulate:a", 1.0, duration)
	await _active_tween.finished
	fade_out_completed.emit()

func fade_in(duration: float = 0.4) -> void:
	if _active_tween and _active_tween.is_running():
		_active_tween.kill()
	_active_tween = create_tween()
	_active_tween.tween_property(color_rect, "modulate:a", 0.0, duration)
	await _active_tween.finished
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_in_completed.emit()
