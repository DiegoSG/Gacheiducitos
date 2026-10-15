extends Node2D

## Prueba del esquive de obstáculos del enemigo base (generic_enemy).
## Coloca al enemigo y a un objetivo con paredes en medio y comprueba que lo alcanza.
## Se ejecuta como escena (necesita los autoloads): imprime [PASS]/[FAIL] y cierra el juego.

const ENEMY_SCENE: PackedScene = preload("res://src/overworld/enemies/generic_enemy.tscn")
const MAX_SECONDS: float = 15.0
const REACH_DISTANCE: float = 48.0

var _passed_count: int = 0
var _failed_count: int = 0

func _ready() -> void:
	print("\n--- TEST: ESQUIVE DE OBSTÁCULOS DEL ENEMIGO ---\n")
	await get_tree().process_frame

	# Pared recta entre el enemigo y el objetivo
	var wall: Array[Rect2] = [Rect2(-20, -120, 40, 240)]
	var reached: bool = await _run_case("pared recta", wall, Vector2(-150, 0), Vector2(150, 0), true)
	_record_result("Rodea una pared recta y alcanza al objetivo", reached)

	# Pared recta, objetivo un poco desviado (la pared desliza hacia un lado)
	reached = await _run_case("pared con objetivo desviado", wall, Vector2(-150, 30), Vector2(150, -20), true)
	_record_result("Rodea una pared con el objetivo desviado", reached)

	# "U" abierta hacia el enemigo: el enemigo entra al bolsillo y tiene que salir
	var pocket: Array[Rect2] = [
		Rect2(40, -120, 40, 240),   # fondo de la U
		Rect2(-120, -120, 160, 30), # brazo superior
		Rect2(-120, 90, 160, 30),   # brazo inferior
	]
	reached = await _run_case("bolsillo en U", pocket, Vector2(-60, 0), Vector2(250, 0), true)
	_record_result("Sale de un bolsillo en U y alcanza al objetivo", reached)

	# Control: sin esquive se queda pegado a la pared (comportamiento anterior)
	reached = await _run_case("sin esquive", wall, Vector2(-150, 0), Vector2(150, 0), false)
	_record_result("Sin esquive se queda pegado (control)", not reached)

	print("\nResultado: %d PASS, %d FAIL" % [_passed_count, _failed_count])
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

	# Objetivo: cuerpo en la capa del jugador, sin hurtbox (así el enemigo nunca "llega a rango")
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
	# Desconecta la zona de pérdida de objetivo para que no interfiera con la prueba
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
	print("  [%s] %s en %.2fs, pos final %s" % [case_name, "alcanzó" if reached else "NO alcanzó", elapsed, enemy.global_position.round()])

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
