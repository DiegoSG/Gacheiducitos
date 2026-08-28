class_name Actionable
extends Area2D

@export var one_shot: bool = false
var triggered: bool = false

func action() -> void:
	if one_shot and triggered: return
	triggered = true
	print("Interacted with " + name)
	# Default behavior: override this in specific interactables
