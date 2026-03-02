class_name Actionable
extends Area2D

# const Balloon = preload("res://scenes/ui/dialogue_balloon.tscn")

func action() -> void:
	print("Interacted with " + name)
	# Default behavior: override this in specific interactables
