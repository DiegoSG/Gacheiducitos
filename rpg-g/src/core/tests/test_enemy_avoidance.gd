extends Node2D

## Tests obstacle avoidance of the base enemy (generic_enemy).
## Places the enemy and a target with walls in between and checks that it reaches the target.
## Runs as a scene (needs the autoloads): prints [PASS]/[FAIL] and quits the game.

const ENEMY_SCENE: PackedScene = preload("res://src/overworld/enemies/generic_enemy.tscn")
const MAX_SECONDS: float = 15.0
const REACH_DISTANCE: float = 48.0

var _passed_count: int = 0
var _failed_count: int = 0

func _ready() -> void:
	print("\n--- TEST: ENEMY OBSTACLE AVOIDANCE ---\n")
	await get_tree().process_frame

	# Straight wall between the enemy and the target
	var wall: Array[Rect2] = [Rect2(-20, -120, 40, 240)]
	var reached: bool = await _run_case("straight wall", wall, Vector2(-150, 0), Vector2(150, 0), true)
	_record_result("Goes around a straight wall and reaches the target", reached)

	# Straight wall, target slightly off to the side (the wall slides to one side)
	reached = await _run_case("wall with off-center target", wall, Vector2(-150, 30), Vector2(150, -20), true)
	_record_result("Goes around a wall with the target off to the side", reached)

	# Open "U" facing the enemy: the enemy enters the pocket and has to get out
	var pocket: Array[Rect2] = [
		Rect2(40, -120, 40, 240),   # bottom of the U
		Rect2(-120, -120, 160, 30), # top arm
		Rect2(-120, 90, 160, 30),   # bottom arm
	]
	reached = await _run_case("U-shaped pocket", pocket, Vector2(-60, 0), Vector2(250, 0), true)
	_record_result("Gets out of a U-shaped pocket and reaches the target", reached)

	# Control: without avoidance it sticks to the wall (previous behavior)
	reached = await _run_case("no avoidance", wall, Vector2(-150, 0), Vector2(150, 0), false)
	_record_result("Without avoidance it sticks to the wall (control)", not reached)

	print("\nResult: %d PASS, %d FAIL" % [_passed_count, _failed_count])
	get_tree().quit(0 if _failed_count == 0 else 1)

func _run_case(case_name: String, walls: Array[Rect2], enemy_pos: Vector2, target_pos: Vector2, avoid: bool) -> bool:
	var world: Node2D = Node2D.new()
	world.name = "World"
	add_child(world)

	for rect: Rect2 in walls:
		var body: StaticBody2D = StaticBody2D.new()
		body.collision_layer = 1
		body.position = rect.get_center()
		var shape: CollisionShape2D = CollisionShape2D.new()
		var rect_shape: RectangleShape2D = RectangleShape2D.new()
		rect_shape.size = rect.size
		shape.shape = rect_shape
		body.add_child(shape)
		world.add_child(body)

	# Target: body on the player's layer, no hurtbox (so the enemy never "gets in range")
	var target: CharacterBody2D = CharacterBody2D.new()
	target.collision_layer = 2
	target.collision_mask = 0
	target.position = target_pos
	world.add_child(target)

	var enemy: CharacterBody2D = ENEMY_SCENE.instantiate()
	enemy.position = enemy_pos
	enemy.avoid_obstacles = avoid
	enemy.cooldown_duration = 0.0
	world.add_child(enemy)
	# Disconnects the lose-target zone so it does not interfere with the test
	enemy.get_node("LoseTargetZone").monitoring = false
	enemy.player = target
	enemy.current_state = enemy.State.CHASE

	var elapsed: float = 0.0
	var reached: bool = false
	while elapsed < MAX_SECONDS:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		if enemy.global_position.distance_to(target.global_position) <= REACH_DISTANCE:
			reached = true
			break
	print("  [%s] %s in %.2fs, final pos %s" % [case_name, "reached" if reached else "did NOT reach", elapsed, enemy.global_position.round()])

	world.queue_free()
	await get_tree().process_frame
	return reached

func _record_result(test_name: String, condition: bool) -> void:
	if condition:
		_passed_count += 1
		print("[PASS] ", test_name)
	else:
		_failed_count += 1
		printerr("[FAIL] ", test_name)
