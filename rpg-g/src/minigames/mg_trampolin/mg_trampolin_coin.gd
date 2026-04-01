extends Area2D

func _enter_tree():
	add_to_group("coin")

signal collected

@export var coin_scale: float = 0.05

func _ready():
	# Usar el icono de oro del proyecto
	if has_node("Sprite2D"):
		var sprite = $Sprite2D
		var tex = load("res://assets/items/icons/coin_v2.png")
		if not tex:
			tex = load("res://assets/items/icons/gold_coins.png")
		sprite.texture = tex
		sprite.modulate = Color.WHITE # Reset modulation
		sprite.scale = Vector2(coin_scale, coin_scale)
	
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body is MG_TrampolinPlayer:
		collected.emit()
		# Feedback visual/sonoro podría ir aquí
		queue_free()
