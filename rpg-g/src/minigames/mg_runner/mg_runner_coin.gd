extends Area2D
class_name MG_RunnerCoin

signal collected

var speed: float = 300.0
@export var coin_scale: float = 0.05

func _ready():
	add_to_group("runner_coin")
	
	if has_node("Sprite2D"):
		var sprite = $Sprite2D
		var tex = load("res://assets/items/icons/coin_v2.png")
		if not tex:
			tex = load("res://assets/items/icons/gold_coins.png")
		sprite.texture = tex
		sprite.modulate = Color.WHITE
		sprite.scale = Vector2(coin_scale, coin_scale)
	
	area_entered.connect(_on_area_entered)

func _process(delta: float):
	position.y += speed * delta
	
	# Destruir si sale de la pantalla
	if global_position.y > 1000:
		queue_free()

func _on_area_entered(area):
	if area is MG_RunnerPlayer:
		collected.emit()
		queue_free()
