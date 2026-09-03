class_name Actionable
extends Area2D

@export var one_shot: bool = false
@export var allow_during_alert: bool = true
var triggered: bool = false

func action() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if not allow_during_alert and gm and gm.has_method("is_in_alert") and gm.is_in_alert():
		print("Actionable: Interaction blocked during alert state for: ", name)
		return
	if one_shot and triggered: return
	triggered = true
	print("Interacted with " + name)
	# Default behavior: override this in specific interactables
