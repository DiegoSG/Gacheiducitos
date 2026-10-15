extends Node

## Prueba de la caminata de salida de portal: carga level_01, viaja a level_02 por el portal
## "1" y comprueba que el jugador termina en el SpawnPoint del portal de llegada, sin rebotar
## de vuelta al nivel anterior. Resultado por consola (PASS/FAIL).

const START_LEVEL: String = "res://src/overworld/levels/level_01.tscn"
const TARGET_LEVEL: String = "res://src/overworld/levels/level_02.tscn"
const ARRIVAL_ID: String = "1"

func _ready() -> void:
	# Esperar a que el árbol termine de montarse antes de cambiar de escena
	await get_tree().process_frame
	# GameManager libera la escena actual al cambiar de nivel: esta escena de prueba no debe ser liberada
	if GameManager.current_scene == self:
		GameManager.current_scene = null
	await GameManager.change_level(START_LEVEL)
	await GameManager.change_level(TARGET_LEVEL, ARRIVAL_ID)
	# Margen para que un rebote por el portal se notara (cambiaría de nuevo de nivel)
	for i: int in 30:
		await get_tree().physics_frame

	var scene: Node = GameManager.current_scene
	var player: Node2D = scene.get_node_or_null("Player") as Node2D
	var portal: LevelPortal = null
	for node: Node in get_tree().get_nodes_in_group("arrival_points"):
		if node is LevelPortal and scene.is_ancestor_of(node) and node.arrival_id == ARRIVAL_ID:
			portal = node
	var failures: int = 0
	if scene.scene_file_path != TARGET_LEVEL:
		failures += 1
		push_error("  FALLA - el jugador no quedó en level_02 (está en %s)" % scene.scene_file_path)
	if player == null or portal == null:
		failures += 1
		push_error("  FALLA - falta el jugador o el portal de llegada")
	else:
		var distance: float = player.global_position.distance_to(portal.get_spawn_position())
		if distance > 2.0:
			failures += 1
			push_error("  FALLA - el jugador quedó a %.1f px del punto de llegada" % distance)
		if not player.is_physics_processing():
			failures += 1
			push_error("  FALLA - el jugador no recuperó el control")
	print("PASS: salida de portal" if failures == 0 else "FAIL: salida de portal (%d)" % failures)
	get_tree().quit()
