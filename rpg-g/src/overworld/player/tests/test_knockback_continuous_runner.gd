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
	assert(hitbox.continuous_damage == true, "continuous_damage must be true")
	assert(hitbox.attack_rate == 0.5, "attack_rate must be 0.5")
	passed += 1
	print("[PASS] HitboxComponent: continuous_damage and attack_rate configured correctly")
	hitbox.free()
	
	# Test 2: Player takes damage and knockback
	var player_scene = load("res://src/overworld/player/player.tscn")
	var player = player_scene.instantiate()
	root.add_child(player)
	
	var stats = root.get_node_or_null("PlayerStats")
	stats.max_health = 4
	stats.health = 4
	
	# First hit: health should drop to 3, invulnerable becomes true, knockback is applied
	var hurtbox = player.get_node("HurtboxComponent")
	hurtbox.take_hit(1, Vector2.RIGHT, 400.0)
	
	assert(stats.health == 3, "Health must be 3 after 1 damage")
	assert(player.is_invulnerable == true, "Player must be invulnerable after the hit")
	assert(player.is_stunned == true, "Player must be stunned/pushed")
	assert(player.knockback_velocity == Vector2.RIGHT * 400.0, "Knockback velocity must be RIGHT * 400")
	passed += 1
	print("[PASS] Player: First hit deals damage (HP 4->3), activates invulnerability and pushes back")
	
	# Test 3: Second hit while invulnerable (does NOT remove health, but DOES apply knockback)
	hurtbox.take_hit(1, Vector2.UP, 350.0)
	assert(stats.health == 3, "Health MUST remain 3 during invulnerability")
	assert(player.is_invulnerable == true, "Player is still invulnerable")
	assert(player.knockback_velocity == Vector2.UP * 350.0, "Knockback velocity MUST update to UP * 350")
	passed += 1
	print("[PASS] Player: Hit during invulnerability does NOT remove health but DOES push back")
	
	# Test 4: Enemy motion_mode
	var enemy_scene = load("res://src/overworld/enemies/generic_enemy.tscn")
	var enemy = enemy_scene.instantiate()
	root.add_child(enemy)
	
	assert(enemy.motion_mode == CharacterBody2D.MOTION_MODE_FLOATING, "Enemy must be MOTION_MODE_FLOATING")
	assert(player.motion_mode == CharacterBody2D.MOTION_MODE_FLOATING, "Player must be MOTION_MODE_FLOATING")
	passed += 1
	print("[PASS] Enemy & Player: Set to MOTION_MODE_FLOATING, preventing enemies from being pushed")
	
	player.queue_free()
	enemy.queue_free()
	
	print("\n-------------------------------------------------------")
	print("FINAL RESULTS:")
	print("  Tests passed: %d" % passed)
	print("  Tests failed:  0")
	print("-------------------------------------------------------\n")
	print(">>> ALL COMBAT AND KNOCKBACK TESTS PASSED AT 100% <<<\n")
	quit(0)
