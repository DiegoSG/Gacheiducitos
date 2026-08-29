class_name Actionable
extends Area2D

@export var one_shot: bool = false
@export var allow_during_alert: bool = true
var triggered: bool = false

func action() -> void:
	if not allow_during_alert and GameManager and GameManager.is_in_alert():
		print("Actionable: Interaction blocked during alert state for: ", name)
		return
	if one_shot and triggered: return
	triggered = true
	print("Interacted with " + name)
	# Default behavior: override this in specific interactables
