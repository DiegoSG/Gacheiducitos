extends SceneTree

## Runner de pruebas automatizadas para Sistema de Muerte, Checkpoints, Snapshots y Respawn.

const CheckpointLevelScript = preload("res://src/overworld/components/checkpoint_level.gd")

var _passed_count: int = 0
var _failed_count: int = 0
var _died_emitted: bool = false

func _on_player_died_test() -> void:
	_died_emitted = true

func _init() -> void:
	print("\n===========================================================")
	print("--- TEST RUNNER: DEATH, CHECKPOINT, SNAPSHOTS & RESPAWN ---")
	print("===========================================================\n")

	await process_frame

	# 1. Obtener los Autoloads oficiales ya instanciados por el Engine
	var inventory: Node = root.get_node("Inventory")
	var player_stats: Node = root.get_node("PlayerStats")
	var world_state: Node = root.get_node("WorldStateManager")
	var gm: Node = root.get_node("GameManager")

	# ========================================================
	# TEST 1: Señal player_died en PlayerStats al llegar a 0 HP
	# ========================================================
	player_stats.max_health = 100
	player_stats.health = 50
	_died_emitted = false
	player_stats.player_died.connect(_on_player_died_test)
	
	player_stats.take_damage(20)
	_record_result("PlayerStats: take_damage resta HP sin emitir muerte prematura", player_stats.health == 30 and not _died_emitted)
	
	player_stats.take_damage(30)
	_record_result("PlayerStats: Al llegar a 0 HP emite player_died", player_stats.health == 0 and _died_emitted)

	# ========================================================
	# TEST 2: Snapshots y Restauración de PlayerStats e Inventory
	# ========================================================
	player_stats.player_died.disconnect(_on_player_died_test)
	player_stats.health = 80
	player_stats.gold = 150
	inventory.items = { "red_potion": 3, "iron_key": 1 }
	
	var stats_snap: Dictionary = player_stats.create_snapshot()
	var inv_snap: Dictionary = inventory.create_snapshot()
	
	# Simular cambios ocurridos en un nivel posterior
	player_stats.health = 10
	player_stats.gold = 30
	inventory.items = { "red_potion": 1, "diamond": 5 }
	
	player_stats.restore_snapshot(stats_snap)
	inventory.restore_snapshot(inv_snap)
	
	var stats_restored: bool = (player_stats.health == 80 and player_stats.gold == 150)
	var inv_restored: bool = (inventory.get_item_count("red_potion") == 3 and inventory.get_item_count("iron_key") == 1 and inventory.get_item_count("diamond") == 0)
	_record_result("PlayerStats: restore_snapshot restaura HP y Oro exactos", stats_restored)
	_record_result("Inventory: restore_snapshot restaura inventario exacto", inv_restored)

	# ========================================================
	# TEST 3: Snapshots y Reversión de WorldStateManager
	# ========================================================
	world_state.clear_all()
	world_state.save_state("chest_lvl1_01", {"opened": true})
	world_state.save_state("door_lvl1_01", {"unlocked": true})
	
	var ws_snap: Dictionary = world_state.create_snapshot()
	
	# Modificaciones en el nivel 2 antes de morir
	world_state.save_state("chest_lvl2_99", {"opened": true})
	world_state.save_state("enemy_boss_lvl2", {"defeated": true})
	
	_record_result("WorldStateManager: Modificaciones temporales registradas en nivel 2", world_state.has_state("chest_lvl2_99"))
	
	# Revertir snapshot al inicio del nivel 2
	world_state.restore_snapshot(ws_snap)
	var ws_reverted: bool = (not world_state.has_state("chest_lvl2_99") and not world_state.has_state("enemy_boss_lvl2") and world_state.has_state("chest_lvl1_01"))
	_record_result("WorldStateManager: restore_snapshot revierte el estado del nivel donde murió sin afectar niveles previos", ws_reverted)

	# ========================================================
	# TEST 4: Registro de Checkpoint y Respawn en GameManager
	# ========================================================
	# Creamos un nodo mock para nivel 1 con CheckpointLevel y un ArrivalSpawnPoint "RespawnPoint"
	var level1: Node2D = Node2D.new()
	level1.name = "Level1Checkpoint"
	level1.scene_file_path = "res://src/overworld/levels/mock_checkpoint_level.tscn"
	
	var cp_component: Node = CheckpointLevelScript.new()
	cp_component.name = "CheckpointLevel"
	level1.add_child(cp_component)
	
	var respawn_marker: Marker2D = Marker2D.new()
	respawn_marker.name = "RespawnMarker"
	respawn_marker.add_to_group("arrival_points")
	respawn_marker.set("arrival_id", "RespawnPoint")
	respawn_marker.position = Vector2(100, 200)
	level1.add_child(respawn_marker)
	
	root.add_child(level1)
	
	# Establecemos estado en Checkpoint
	player_stats.health = 100
	player_stats.gold = 500
	inventory.items = { "ancient_map": 1 }
	
	gm.register_level_entry(level1.scene_file_path, level1)
	_record_result("GameManager: Registra active_checkpoint_scene_path al detectar CheckpointLevel", gm.active_checkpoint_scene_path == level1.scene_file_path)
	
	# Entramos a un Nivel 2 (No Checkpoint)
	var level2: Node2D = Node2D.new()
	level2.name = "Level2Danger"
	level2.scene_file_path = "res://src/overworld/levels/Lvl01.tscn"
	root.add_child(level2)
	
	# Al ENTRAR al nivel 2, se registra la entrada y se toma el snapshot de persistencia
	gm.register_level_entry(level2.scene_file_path, level2)
	_record_result("GameManager: Checkpoint activo sigue siendo Nivel 1 tras entrar a Nivel 2", gm.active_checkpoint_scene_path == level1.scene_file_path)

	# DENTRO del Nivel 2, el jugador sufre daño, gasta oro, recoge un ítem y modifica el mundo
	player_stats.health = 20
	player_stats.gold = 100
	inventory.items["gem"] = 1
	world_state.save_state("lvl2_item_picked", {"picked": true})
	
	# Simulamos el Respawn del jugador tras morir en el Nivel 2
	gm.current_scene = level2
	await gm.respawn_player()
	
	var respawn_stats_ok: bool = (player_stats.health == 100 and player_stats.gold == 500)
	var respawn_inv_ok: bool = (inventory.get_item_count("ancient_map") == 1 and inventory.get_item_count("gem") == 0)
	var respawn_ws_ok: bool = not world_state.has_state("lvl2_item_picked")
	
	_record_result("GameManager.respawn_player: Restaura stats del checkpoint activo", respawn_stats_ok)
	_record_result("GameManager.respawn_player: Restaura inventario del checkpoint activo", respawn_inv_ok)
	_record_result("GameManager.respawn_player: Revierte persistencias del nivel 2", respawn_ws_ok)

	# ====================================================
	# RESUMEN FINAL
	# ====================================================
	print("\n-------------------------------------------------------")
	print("RESULTADOS FINALES:")
	print("  Pruebas superadas: ", _passed_count)
	print("  Pruebas fallidas:  ", _failed_count)
	print("-------------------------------------------------------")

	level1.queue_free()
	level2.queue_free()

	if _failed_count == 0:
		print("\n>>> TODOS LOS TESTS DE MUERTE, CHECKPOINTS Y RESPAWN PASARON AL 100% <<<\n")
		quit(0)
	else:
		push_error("Se detectaron fallos en la batería de pruebas de respawn.")
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
