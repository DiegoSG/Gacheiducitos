extends Node

## Tests the portal exit walk: loads level_01, travels to level_02 through the portal
## "1" and checks that the player ends at the SpawnPoint of the arrival portal, without bouncing
## back to the previous level. Console result (PASS/FAIL).

const START_LEVEL: String = "res://src/overworld/levels/level_01.tscn"
const TARGET_LEVEL: String = "res://src/overworld/levels/level_02.tscn"
const ARRIVAL_ID: String = "1"

func _ready() -> void:
	# Wait for the tree to finish mounting before changing scene
	await get_tree().process_frame
	# GameManager frees the current scene when changing level: this test scene must not be freed
	if GameManager.current_scene == self:
		GameManager.current_scene = null
	await GameManager.change_level(START_LEVEL)
	await GameManager.change_level(TARGET_LEVEL, ARRIVAL_ID)
	# Margin so a bounce back through the portal would be noticed (it would change level again)
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
		push_error("  FAIL - the player is not in level_02 (is in %s)" % scene.scene_file_path)
	if player == null or portal == null:
		failures += 1
		push_error("  FAIL - missing the player or the arrival portal")
	else:
		var distance: float = player.global_position.distance_to(portal.get_spawn_position())
		if distance > 2.0:
			failures += 1
			push_error("  FAIL - the player is %.1f px from the arrival point" % distance)
		if not player.is_physics_processing():
			failures += 1
			push_error("  FAIL - the player did not regain control")
	print("PASS: portal exit" if failures == 0 else "FAIL: portal exit (%d)" % failures)
	get_tree().quit()
