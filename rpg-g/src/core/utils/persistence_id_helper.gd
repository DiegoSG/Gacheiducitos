@tool
class_name PersistenceIdHelper
extends RefCounted

## Utilidad estática para generar identificadores únicos, deterministas
## y reproducibles de persistencia basados en la ruta de escena y jerarquía del nodo.
##
## IMPORTANTE: El ID generado es estable entre ejecuciones porque se basa en
## la ruta del archivo de escena y la posición jerárquica del nodo (NO en randi()).


static func generate_id(node: Node, prefix: String = "") -> String:
	if not node:
		return ""

	# 1. Identificador de escena raíz estable (basado en el archivo .tscn)
	var scene_id: String = "scene"
	var root: Node = node.owner
	if not root and node.get_tree():
		root = node.get_tree().current_scene

	if root:
		if not root.scene_file_path.is_empty():
			scene_id = root.scene_file_path.get_file().get_basename().to_snake_case()
		elif not root.name.is_empty():
			scene_id = root.name.to_snake_case()

	# 2. Ruta jerárquica estricta dentro de la escena (garantiza unicidad entre hermanos)
	var rel_path: String = ""
	if root and root != node:
		rel_path = str(root.get_path_to(node))
	else:
		rel_path = str(node.get_path()) if node.is_inside_tree() else str(node.name)

	# 3. Hash MD5 determinista de 8 caracteres (100% reproducible entre ejecuciones)
	var full_signature: String = "%s:%s" % [scene_id, rel_path]
	var deterministic_hash: String = full_signature.md5_text().substr(0, 8)

	var tag: String = prefix if not prefix.is_empty() else node.name.to_snake_case()
	return "%s_%s_%s" % [scene_id, tag, deterministic_hash]


## Clave de persistencia a usar en runtime.
## Si [param explicit_id] tiene valor, el estado es permanente (se guarda en la partida).
## Si está vacío, devuelve una clave "efímera" basada en la ruta del nodo: el estado dura
## solo mientras el jugador siga en el nivel (WorldStateManager la limpia al cambiar de nivel).
## Nunca asignes el resultado a la propiedad exportada persistence_id: en scripts @tool
## quedaría guardado dentro de la escena.
static func runtime_key(node: Node, explicit_id: String) -> String:
	if not explicit_id.is_empty():
		return explicit_id
	if node.owner:
		return "ephemeral_" + str(node.owner.get_path_to(node))
	return str(node.get_path()) + "_ephemeral"
