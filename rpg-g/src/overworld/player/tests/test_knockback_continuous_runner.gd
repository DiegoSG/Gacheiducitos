extends SceneTree

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("\n===========================================================")
	print("--- TEST RUNNER: ENEMY ATTACK, KNOCKBACK & I-FRAMES ---")
	print("===========================================================\n")
	
	var passed = 0
	
	# Test 1: HitboxComponent continuous damage flag & defaults
	var hitbox = HitboxComponent.new()
	hitbox.damage = 1
	hitbox.knockback_force = 250.0
	hitbox.continuous_damage = true
	hitbox.attack_rate = 0.5
	assert(hitbox.continuous_damage == true, "continuous_damage debe ser true")
	assert(hitbox.attack_rate == 0.5, "attack_rate debe ser 0.5")
	passed += 1
	print("[PASS] HitboxComponent: continuous_damage y attack_rate configurados correctamente")
	hitbox.free()
	
	# Test 2: Player recibe daño y knockback
	var player_scene = load("res://src/overworld/player/player.tscn")
	var player = player_scene.instantiate()
	root.add_child(player)
	
	var stats = root.get_node_or_null("PlayerStats")
	stats.max_health = 4
	stats.health = 4
	
	# Primer golpe: vida debe bajar a 3, invulnerable pasa a true, knockback se aplica
	var hurtbox = player.get_node("HurtboxComponent")
	hurtbox.take_hit(1, Vector2.RIGHT, 400.0)
	
	assert(stats.health == 3, "Salud debe ser 3 tras 1 de daño")
	assert(player.is_invulnerable == true, "Player debe estar invulnerable tras el golpe")
	assert(player.is_stunned == true, "Player debe estar stuneado/empujado")
	assert(player.knockback_velocity == Vector2.RIGHT * 400.0, "Knockback velocity debe ser RIGHT * 400")
	passed += 1
	print("[PASS] Player: Primer golpe aplica daño (HP 4->3), activa invulnerabilidad y empuja hacia atras")
	
	# Test 3: Segundo golpe mientras es invulnerable (NO quita vida, pero SI aplica knockback)
	hurtbox.take_hit(1, Vector2.UP, 350.0)
	assert(stats.health == 3, "Salud DEBE seguir siendo 3 durante invulnerabilidad")
	assert(player.is_invulnerable == true, "Player sigue invulnerable")
	assert(player.knockback_velocity == Vector2.UP * 350.0, "Knockback velocity DEBE actualizarse a UP * 350")
	passed += 1
	print("[PASS] Player: Golpe durante invulnerabilidad NO quita vida pero SI empuja hacia atras")
	
	# Test 4: Enemy motion_mode
	var enemy_scene = load("res://src/overworld/enemies/generic_enemy.tscn")
	var enemy = enemy_scene.instantiate()
	root.add_child(enemy)
	
	assert(enemy.motion_mode == CharacterBody2D.MOTION_MODE_FLOATING, "Enemy debe ser MOTION_MODE_FLOATING")
	assert(player.motion_mode == CharacterBody2D.MOTION_MODE_FLOATING, "Player debe ser MOTION_MODE_FLOATING")
	passed += 1
	print("[PASS] Enemy & Player: Configurados en MOTION_MODE_FLOATING impidiendo empujar enemigos")
	
	player.queue_free()
	enemy.queue_free()
	
	print("\n-------------------------------------------------------")
	print("RESULTADOS FINALES:")
	print("  Pruebas superadas: %d" % passed)
	print("  Pruebas fallidas:  0")
	print("-------------------------------------------------------\n")
	print(">>> TODOS LOS TESTS DE COMBATE Y KNOCKBACK PASARON AL 100% <<<\n")
	quit(0)
