class_name SpawnAction
extends ActionResource

## Instancia (spawnea) una escena en el escenario usando la posición de un objeto de referencia o un marcador.

## Escena a spawnear (enemigo, cofre, ítem, efecto, etc.)
@export var scene_to_spawn: PackedScene

@export_group("Ubicación de Spawn")
## Nodo de referencia para la posición (Marker2D, Node2D, etc.). Si está asignado, spawnea exactamente en su posición global.
@export var spawn_target_node: NodePath

## Desplazamiento adicional opcional sobre la posición del target o del padre
@export var offset: Vector2 = Vector2.ZERO

@export_group("Jerarquía")
## Nodo que será el padre de la escena instanciada (opcional). Si está vacío, se agrega al árbol del nivel actual.
@export var parent_path: NodePath = ""

func get_action_name() -> String:
	return "SpawnAction (%s en %s)" % [
		scene_to_spawn.resource_path.get_file() if scene_to_spawn else "None",
		str(spawn_target_node) if not spawn_target_node.is_empty() else "Self"
	]

func execute(trigger_node: Node) -> void:
	if not scene_to_spawn:
		push_warning("SpawnAction: scene_to_spawn no está asignada.")
		finished.emit()
		return

	var target_ref: Node = null
	if not spawn_target_node.is_empty():
		target_ref = trigger_node.get_node_or_null(spawn_target_node)

	# Si no se asignó o no se encontró el target_node, usar el trigger_node como posición
	var spawn_pos: Vector2 = Vector2.ZERO
	if target_ref is Node2D:
		spawn_pos = (target_ref as Node2D).global_position + offset
	elif trigger_node is Node2D:
		spawn_pos = (trigger_node as Node2D).global_position + offset

	# Determinar el padre donde se añadirá
	var parent_node: Node = null
	if not parent_path.is_empty():
		parent_node = trigger_node.get_node_or_null(parent_path)
	
	if not parent_node:
		# Añadir a la raíz del nivel / escena actual
		parent_node = trigger_node.get_tree().current_scene if trigger_node.get_tree() else trigger_node.get_parent()
		
	if parent_node:
		var instance: Node = scene_to_spawn.instantiate()
		parent_node.add_child(instance)
		
		if instance is Node2D:
			(instance as Node2D).global_position = spawn_pos
			
		print("[SpawnAction]: '%s' spawneado en posición global %s" % [instance.name, str(spawn_pos)])

	finished.emit()
