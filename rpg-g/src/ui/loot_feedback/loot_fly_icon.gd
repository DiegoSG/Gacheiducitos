extends Control
class_name LootFlyIcon

@onready var texture_rect: TextureRect = $TextureRect
@onready var amount_label: Label = $AmountLabel

func setup(texture: Texture2D, amount: int = 1) -> void:
	if texture_rect:
		texture_rect.texture = texture
	if amount_label:
		if amount > 1:
			amount_label.text = "+%d" % amount
			amount_label.visible = true
		else:
			amount_label.visible = false

func animate_to(start_screen_pos: Vector2, target_screen_pos: Vector2, on_complete: Callable = Callable()) -> void:
	global_position = start_screen_pos - size * 0.5
	scale = Vector2(0.2, 0.2)
	modulate.a = 0.0

	var tween: Tween = create_tween()
	# Fase 1: Pop up inicial (aparece y se agranda un poco)
	var peak_pos: Vector2 = start_screen_pos + Vector2(randf_range(-30, 30), -50) - size * 0.5
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", peak_pos, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.15)
	
	# Fase 2: Vuelo curvo hacia el objetivo en la UI
	tween.chain().set_parallel(true)
	var end_pos: Vector2 = target_screen_pos - size * 0.5
	tween.tween_property(self, "global_position", end_pos, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(0.5, 0.5), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Finalización
	tween.chain().tween_callback(func():
		if on_complete.is_valid():
			on_complete.call()
		queue_free()
	)
