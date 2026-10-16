class_name DropLootAction
extends ActionResource

## Suelta en el mundo ítems de una lista (oro incluido), cada uno con su probabilidad.
## Sirve en cualquier lista de acciones: muerte de un enemigo (GenericEnemy.on_defeat_actions),
## GameTrigger, DialogueEvent, placas, interruptores...
##
## En cada ejecución se tira la probabilidad de cada entrada; de las que salen se sueltan
## como máximo drop_count, al azar. Con probabilidad 100 un ítem sale siempre.
## Para ítems especiales: una acción aparte con one_shot y persistence_id.

## Lista de ítems posibles.
@export var entries: Array[LootEntry] = []
## Cuántos ítems distintos de la lista puede soltar como máximo en cada ejecución.
@export_range(1, 20) var drop_count: int = 1

@export_group("Repetición")
## Si es true, suelta una sola vez en toda la partida; si es false, cada vez que se ejecuta.
@export var one_shot: bool = false
## ID con el que se guarda que ya soltó (solo con one_shot).
## Vacío: usa el persistence_id del nodo que la ejecuta + "_loot". Si tampoco hay, la marca
## dura solo mientras el jugador siga en el nivel.
@export var persistence_id: String = ""

@export_group("Spawn")
## Punto desde donde caen los ítems (ej. un Marker2D), relativo al nodo que ejecuta la acción.
## Vacío: el pivote de ese nodo (el enemigo, el trigger...).
@export var spawn_at: NodePath = NodePath("")
@export var pickup_item_scene: PackedScene = preload("res://src/overworld/interactables/pickup_item.tscn")
## Radio máximo de dispersión para que los ítems no se amontonen.
@export var scatter_radius: float = 24.0
## Tiempo que tarda un ítem en caer a su posición antes de poder recogerse.
@export var drop_duration: float = 0.45
## Retraso escalonado entre ítems para que no salgan todos a la vez.
@export var scatter_delay: float = 0.05

@export_group("Evento (opcional)")
## Evento global que se dispara si soltó al menos un ítem.
@export var on_dropped_event: String = ""

func get_action_name() -> String:
	return "DropLootAction (%d entradas, máx %d%s)" % [entries.size(), drop_count, ", una vez" if one_shot else ""]

func execute(trigger_node: Node) -> void:
	if trigger_node == null or not trigger_node.is_inside_tree():
		push_warning("DropLootAction: el nodo que la ejecuta no está en la escena.")
		finished.emit()
		return

	var key: String = _state_key(trigger_node)
	if one_shot and _already_dropped(key):
		finished.emit()
		return

	var spawned: Array[PickupItem] = drop(trigger_node)
	if one_shot and not spawned.is_empty():
		WorldStateManager.save_state(key, {"dropped": true})
	if not spawned.is_empty():
		emit_game_event(on_dropped_event)
	finished.emit()

## Tira la lista y crea los PickupItem. Devuelve los ítems creados.
func drop(trigger_node: Node) -> Array[PickupItem]:
	var spawned: Array[PickupItem] = []
	var candidates: Array[LootEntry] = []
	for entry: LootEntry in entries:
		if entry and entry.item and _roll(entry.chance):
			candidates.append(entry)
	if candidates.is_empty():
		return spawned

	candidates.shuffle()
	var origin: Vector2 = _spawn_origin(trigger_node)
	var parent: Node = _spawn_parent(trigger_node)
	var drop_index: int = 0
	for i: int in range(mini(drop_count, candidates.size())):
		var entry: LootEntry = candidates[i]
		var amount: int = randi_range(mini(entry.min_amount, entry.max_amount), maxi(entry.min_amount, entry.max_amount))
		if amount <= 0:
			continue
		var pickup: PickupItem = _spawn_pickup(entry.item, amount, origin, parent, drop_index)
		if pickup:
			spawned.append(pickup)
			drop_index += 1

	if not spawned.is_empty():
		AudioManager.play_sfx(&"sfx_enemy_loot_drop")
	return spawned

func _roll(chance: int) -> bool:
	if chance <= 0:
		return false
	if chance >= 100:
		return true
	return randi_range(1, 100) <= chance

func _state_key(trigger_node: Node) -> String:
	if not persistence_id.is_empty():
		return persistence_id
	var owner_id: Variant = trigger_node.get("persistence_id")
	if owner_id is String and not (owner_id as String).is_empty():
		return (owner_id as String) + "_loot"
	return PersistenceIdHelper.runtime_key(trigger_node, "") + "_loot"

func _already_dropped(key: String) -> bool:
	if not WorldStateManager.has_state(key):
		return false
	var data: Dictionary = WorldStateManager.load_state(key)
	# "unique_dropped" es la marca que guardaba el antiguo LootDropComponent (saves viejos)
	return data.get("dropped", false) or data.get("unique_dropped", false)

func _spawn_origin(trigger_node: Node) -> Vector2:
	var at: Node = trigger_node.get_node_or_null(spawn_at) if not spawn_at.is_empty() else trigger_node
	if at is Node2D:
		return (at as Node2D).global_position
	if trigger_node is Node2D:
		return (trigger_node as Node2D).global_position
	return Vector2.ZERO

## Los ítems van al padre del nodo que ejecuta (el nivel), así no desaparecen si ese nodo se borra.
func _spawn_parent(trigger_node: Node) -> Node:
	if trigger_node.get_parent():
		return trigger_node.get_parent()
	return trigger_node.get_tree().current_scene

func _spawn_pickup(item: ItemData, amount: int, origin: Vector2, parent: Node, delay_step: int) -> PickupItem:
	if pickup_item_scene == null or parent == null:
		return null
	var pickup: PickupItem = pickup_item_scene.instantiate() as PickupItem
	if pickup == null:
		return null
	pickup.item_data = item
	pickup.custom_amount = amount

	var angle: float = randf() * TAU
	var distance: float = randf_range(12.0, maxf(12.0, scatter_radius))
	var target: Vector2 = origin + Vector2(cos(angle), sin(angle)) * distance
	pickup.animate_drop_from(origin, target, drop_duration + float(delay_step) * scatter_delay)
	parent.call_deferred("add_child", pickup)
	return pickup
