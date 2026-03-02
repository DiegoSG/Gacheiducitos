extends Node

# Singleton to manage game state and scene transitions

var current_scene = null
var previous_scene_path = ""
var player_return_position = Vector2.ZERO

# Configuración de minijuego (para debug y persistencia)
var minigame_config = {}
var current_level_seed = -1

func _ready():
	var root = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)

func load_minigame(minigame_path: String, player_pos: Vector2 = Vector2.ZERO):
	if current_scene:
		# Solo guardar la escena previa si NO es ya parte del minijuego
		# (Para que el debug screen no sobrescriba el Overworld)
		if not ("minigames" in current_scene.scene_file_path):
			previous_scene_path = current_scene.scene_file_path
			player_return_position = player_pos
			print("GameManager: Saved return path: ", previous_scene_path)
		
	call_deferred("_deferred_load_minigame", minigame_path)

func _deferred_load_minigame(path):
	# Save current scene reference if needed, or just free it
	if current_scene:
		current_scene.free()
	
	var s = ResourceLoader.load(path)
	current_scene = s.instantiate()
	get_tree().root.add_child(current_scene)
	get_tree().current_scene = current_scene
	
	# If returning to Overworld, restore player position
	if path == previous_scene_path and player_return_position != Vector2.ZERO:
		if current_scene.has_node("Player"):
			current_scene.get_node("Player").position = player_return_position

func return_to_overworld():
	print("GameManager: return_to_overworld called")
	var target_scene = previous_scene_path if previous_scene_path != "" else "res://scenes/overworld/overworld.tscn"
	print("GameManager: target_scene = ", target_scene)
	call_deferred("_deferred_load_minigame", target_scene)
