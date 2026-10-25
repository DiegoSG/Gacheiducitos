extends SceneTree

## Runner de pruebas unitarias y de integración para PlayerHUD (barritas verticales y oro)
## y daño configurable en GenericEnemy.

const GenericEnemyScene = preload("res://src/overworld/enemies/generic_enemy.tscn")
const PlayerHUDScene = preload("res://src/ui/loot_feedback/player_hud.tscn")

var _passed_count: int = 0
var _failed_count: int = 0

func _init() -> void:
	print("\n=======================================================")
	print("--- TEST RUNNER: PLAYER HUD & ENEMY CONFIGURABLE DAMAGE ---")
	print("=======================================================\n")

	await process_frame

	var player_stats = root.get_node("PlayerStats")

	# ========================================================
	# TEST 1: attack_damage configurable en GenericEnemy
	# ========================================================
	var enemy1 = GenericEnemyScene.instantiate()
	enemy1.attack_damage = 2
	root.add_child(enemy1)
	
	await process_frame
	var enemy_dmg_ok: bool = (enemy1.hitbox_component.damage == 2)
	_record_result("GenericEnemy: attack_damage expuesto se transfiere a hitbox_component.damage", enemy_dmg_ok)
	enemy1.queue_free()

	# ========================================================
	# TEST 2: Inicialización de PlayerHUD con 4 barritas
	# ========================================================
	player_stats.max_health = 4
	player_stats.health = 4
	player_stats.gold = 50

	var hud: LootFeedbackManager = PlayerHUDScene.instantiate() as LootFeedbackManager
	root.add_child(hud)
	await process_frame

	var pips_container = hud.get_node_or_null("TopLeftContainer/VBoxContainer/HealthBarContainer")
	var gold_lbl = hud.get_node_or_null("TopLeftContainer/VBoxContainer/GoldContainer/GoldLabel")

	var hud_found: bool = (pips_container != null and gold_lbl != null)
	_record_result("PlayerHUD: TopLeftContainer contiene HealthBarContainer y GoldContainer", hud_found)

	var pips_count: int = pips_container.get_child_count() if pips_container else 0
	_record_result("PlayerHUD: Genera exactamente 4 barritas verticales para max_health = 4", pips_count == 4)

	# Verificar que todas las 4 estén activas (verdes)
	var all_active: bool = true
	for child in pips_container.get_children():
		if child is ColorRect and child.color != LootFeedbackManager.COLOR_HEALTH_ACTIVE:
			all_active = false
	_record_result("PlayerHUD: Las 4 barritas inician activas al tener vida llena", all_active)

	# ========================================================
	# TEST 3: Daño recibido apaga la cantidad exacta de barritas
	# ========================================================
	player_stats.take_damage(1) # Vida baja de 4 a 3
	await process_frame

	var pips = pips_container.get_children()
	var active_count: int = 0
	var empty_count: int = 0
	for pip in pips:
		if pip is ColorRect:
			if pip.color == LootFeedbackManager.COLOR_HEALTH_ACTIVE:
				active_count += 1
			elif pip.color == LootFeedbackManager.COLOR_HEALTH_EMPTY:
				empty_count += 1

	_record_result("PlayerHUD: Al recibir 1 de daño, quedan 3 activas y 1 apagada", active_count == 3 and empty_count == 1)

	# Daño adicional de 2 (Vida baja a 1)
	player_stats.take_damage(2)
	await process_frame

	active_count = 0
	empty_count = 0
	for pip in pips_container.get_children():
		if pip is ColorRect:
			if pip.color == LootFeedbackManager.COLOR_HEALTH_ACTIVE:
				active_count += 1
			elif pip.color == LootFeedbackManager.COLOR_HEALTH_EMPTY:
				empty_count += 1

	_record_result("PlayerHUD: Al recibir 2 de daño adicional, queda 1 activa y 3 apagadas", active_count == 1 and empty_count == 3)

	# ========================================================
	# TEST 4: Expansión dinámica si max_health aumenta
	# ========================================================
	player_stats.max_health = 6
	player_stats.health = 5
	await process_frame

	var new_pips_count = pips_container.get_child_count()
	_record_result("PlayerHUD: Aumentar max_health a 6 crea 6 barritas dinámicamente", new_pips_count == 6)

	# ========================================================
	# TEST 5: Sincronización del Contador de Oro
	# ========================================================
	player_stats.add_gold(75)
	await process_frame
	_record_result("PlayerHUD: GoldLabel refleja el oro exacto (50 + 75 = 125)", gold_lbl.text == "125")

	# ========================================================
	# RESUMEN
	# ========================================================
	print("\n-------------------------------------------------------")
	print("RESULTADOS FINALES:")
	print("  Pruebas superadas: ", _passed_count)
	print("  Pruebas fallidas:  ", _failed_count)
	print("-------------------------------------------------------")

	hud.queue_free()

	if _failed_count == 0:
		print("\n>>> TODOS LOS TESTS DE PLAYER HUD PASARON AL 100% <<<\n")
		quit(0)
	else:
		push_error("Fallos detectados en test runner de PlayerHUD.")
		quit(1)

func _record_result(test_name: String, success: bool, extra_info: String = "") -> void:
	if success:
		_passed_count += 1
		print("[PASS] %s" % test_name)
	else:
		_failed_count += 1
		var err_msg = "[FAIL] %s" % test_name
		if not extra_info.is_empty():
			err_msg += " -> " + extra_info
		push_error(err_msg)
		print(err_msg)
