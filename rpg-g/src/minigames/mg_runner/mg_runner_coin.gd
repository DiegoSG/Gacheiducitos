extends Area2D
class_name MG_RunnerCoin

signal collected

var speed: float = 350.0
@export var coin_scale: float = 0.9

func _ready() -> void:
	add_to_group("runner_coin")
	add_to_group("runner_pickup")
	
	if has_node("Sprite2D"):
		var sprite = $Sprite2D
		var tex = load("res://assets/items/icons/coin_v2.png")
		if not tex:
			tex = load("res://assets/items/icons/gold_coins.png")
		if tex:
			sprite.texture = tex
			sprite.modulate = Color.WHITE
			sprite.scale = Vector2(coin_scale, coin_scale)
	
	area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	position.x -= speed * delta
	
	if position.x < -200.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area is MG_RunnerPlayer and not area.is_dead:
		collected.emit()
		queue_free()
