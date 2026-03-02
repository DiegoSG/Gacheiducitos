extends Node2D

func _process(delta):
	if Input.is_action_just_pressed("ui_cancel"): # ESC key usually
		GameManager.return_to_overworld()
