extends Area2D
class_name MG_RunnerBullet

var speed: float = 600.0
var player

func _ready():
	add_to_group("runner_bullet")
	area_entered.connect(_on_area_entered)

func _process(delta: float):
	position.y -= speed * delta
	
	if global_position.y < -100:
		queue_free()

func _on_area_entered(area):
	if area is MG_RunnerEnemy:
		if player:
			player.add_ammo(1)
		area.die()
		queue_free()
