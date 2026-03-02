extends Actionable

func action() -> void:
	print("Chest opened!")
	# Visual feedback: changing color or just printing for now
	$Sprite2D.modulate = Color(1, 1, 0) # Turn yellow
	# queue_free() 
