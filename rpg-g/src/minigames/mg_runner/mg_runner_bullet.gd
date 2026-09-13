extends Area2D
class_name MG_RunnerBullet

var speed: float = 750.0
var player: MG_RunnerPlayer

func _ready() -> void:
	add_to_group("runner_bullet")
	area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	position.x += speed * delta
	
	if position.x > 2100.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area is MG_RunnerEnemy:
		if player:
			player.add_ammo(1)
		area.die()
		queue_free()
	elif area is MG_RunnerObstacle:
		if area.obstacle_type == MG_RunnerObstacle.ObstacleType.TALL or area.obstacle_type == MG_RunnerObstacle.ObstacleType.HIGH:
			area.hit_by_bullet()
			queue_free()
