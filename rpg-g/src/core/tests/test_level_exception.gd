extends Node

## Test unitario y de integración para validar la Excepción de Autoguardado (LevelExceptionConfig)
## y el registro de active_checkpoint_spawn_id en CheckpointManager.

var _autosave_count: int = 0
var _passed_count: int = 0
var _failed_count: int = 0

func _on_game_saved(slot_id: int) -> void:
	var ss = get_node_or_null("/root/SaveSystem")
	if ss and slot_id == ss.AUTOSAVE_SLOT_ID:
		_autosave_count += 1

func _record_result(test_name: String, condition: bool) -> void:
	if condition:
		_passed_count += 1
		print("[PASS] ", test_name)
	else:
		_failed_count += 1
		printerr("[FAIL] ", test_name)

func _ready() -> void:
	print("\n=======================================================")
	print("--- TEST RUNNER: AUTOSAVE EXCEPTION & RESPAWN SPAWN ID ---")
	print("=======================================================\n")
	
	await get_tree().process_frame
	
	var ss = get_node_or_null("/root/SaveSystem")
	var cm = get_node_or_null("/root/CheckpointManager")
	var gm = get_node_or_null("/root/GameManager")
	
	assert(ss != null, "SaveSystem debe existir como Autoload")
	assert(cm != null, "CheckpointManager debe existir como Autoload")
	
	ss.game_saved.connect(_on_game_saved)
	
	# Asegurar que GameManager tiene una escena válida para permitir guardado si aplica
	if gm and not is_instance_valid(gm.current_scene):
		gm.current_scene = self
	
	# -------------------------------------------------------------
	# TEST 1: Nivel estándar (sin excepción) ejecuta autoguardado en transición orgánica
	# -------------------------------------------------------------
	var standard_level := Node2D.new()
	standard_level.name = "StandardLevel"
	standard_level.scene_file_path = "res://src/overworld/levels/Lvl01.tscn"
	add_child(standard_level)
	
	_autosave_count = 0
	cm.active_checkpoint_scene_path = ""
	cm.active_checkpoint_spawn_id = ""
	
	cm.register_level_entry(standard_level.scene_file_path, standard_level, true)
	
	_record_result("Nivel estándar: registra active_checkpoint_scene_path normal", cm.active_checkpoint_scene_path == standard_level.scene_file_path)
	_record_result("Nivel estándar: active_checkpoint_spawn_id permanece vacío", cm.active_checkpoint_spawn_id == "")
	_record_result("Nivel estándar: ejecuta autoguardado orgánico (slot 0)", _autosave_count == 1)
	
	# -------------------------------------------------------------
	# TEST 2: Nivel con LevelExceptionConfig (disable_autosave = true)
	#         debe OMITIR autoguardado y guardar respawn_level_path y respawn_spawn_id
	# -------------------------------------------------------------
	var exception_level := Node2D.new()
	exception_level.name = "BossDangerRoom"
	exception_level.scene_file_path = "res://src/overworld/levels/BossRoom.tscn"
	
	var exception_config := LevelExceptionConfig.new()
	exception_config.name = "LevelExceptionConfig"
	exception_config.disable_autosave = true
	exception_config.respawn_level_path = "res://src/overworld/levels/Lvl01.tscn"
	exception_config.respawn_spawn_id = "BossDoorEntrance"
	exception_level.add_child(exception_config)
	add_child(exception_level)
	
	_autosave_count = 0
	cm.register_level_entry(exception_level.scene_file_path, exception_level, true)
	
	_record_result("Excepción activa: autoguardado salta/se omite", _autosave_count == 0)
	_record_result("Excepción activa: active_checkpoint_scene_path actualizado a respawn_level_path", cm.active_checkpoint_scene_path == "res://src/overworld/levels/Lvl01.tscn")
	_record_result("Excepción activa: active_checkpoint_spawn_id registrado correctamente", cm.active_checkpoint_spawn_id == "BossDoorEntrance")
	
	# -------------------------------------------------------------
	# TEST 3: Nivel con LevelExceptionConfig pero disable_autosave = false
	#         debe permitir autoguardado y registrar el spawn_id
	# -------------------------------------------------------------
	var allowed_level := Node2D.new()
	allowed_level.name = "SubHubRoom"
	allowed_level.scene_file_path = "res://src/overworld/levels/SubHub.tscn"
	
	var allowed_config := LevelExceptionConfig.new()
	allowed_config.name = "LevelExceptionConfig"
	allowed_config.disable_autosave = false
	allowed_config.respawn_level_path = "res://src/overworld/levels/Lvl02.tscn"
	allowed_config.respawn_spawn_id = "SubHubSpawn"
	allowed_level.add_child(allowed_config)
	add_child(allowed_level)
	
	_autosave_count = 0
	cm.register_level_entry(allowed_level.scene_file_path, allowed_level, true)
	
	_record_result("Excepción con disable_autosave=false: ejecuta autoguardado", _autosave_count == 1)
	_record_result("Excepción con disable_autosave=false: active_checkpoint_scene_path actualizado", cm.active_checkpoint_scene_path == "res://src/overworld/levels/Lvl02.tscn")
	_record_result("Excepción con disable_autosave=false: active_checkpoint_spawn_id registrado", cm.active_checkpoint_spawn_id == "SubHubSpawn")
	
	# -------------------------------------------------------------
	# TEST 4: Transición no orgánica (carga de partida) no debe autoguardar
	# -------------------------------------------------------------
	var non_organic_level := Node2D.new()
	non_organic_level.name = "LoadedLevel"
	non_organic_level.scene_file_path = "res://src/overworld/levels/Lvl03.tscn"
	add_child(non_organic_level)
	
	_autosave_count = 0
	cm.register_level_entry(non_organic_level.scene_file_path, non_organic_level, false)
	_record_result("Transición no orgánica: no ejecuta autoguardado", _autosave_count == 0)
	
	# Limpieza de nodos creados para la prueba
	standard_level.queue_free()
	exception_level.queue_free()
	allowed_level.queue_free()
	non_organic_level.queue_free()
	
	print("\n-------------------------------------------------------")
	print("RESULTADOS TEST: ", _passed_count, " PASADOS, ", _failed_count, " FALLADOS")
	print("-------------------------------------------------------\n")
	
	if _failed_count > 0:
		push_error("[TestRunner] Hubo fallos en las pruebas.")
		get_tree().quit(1)
	else:
		print("[TestRunner] Todas las pruebas pasaron satisfactoriamente.")
		get_tree().quit(0)
