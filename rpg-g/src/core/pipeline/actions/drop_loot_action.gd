class_name DropLootAction
extends ActionResource

## Drops items from a list (gold included) into the world, each one with its own chance.
## Works in any action list: enemy death (GenericEnemy.on_defeat_actions),
## GameTrigger, DialogueEvent, pressure plates, switches...
##
## Each run rolls every entry's chance; from the ones that pass, at most drop_count
## are dropped, picked at random. An item with chance 100 always passes.
## For special items: use a separate action with one_shot and persistence_id.

## Possible items.
@export var entries: Array[LootEntry] = []
## Maximum number of different entries dropped per run.
@export_range(1, 20) var drop_count: int = 1

@export_group("Repeat")
## If true, drops only once per save file; if false, every time it runs.
@export var one_shot: bool = false
## ID used to save that it already dropped (only with one_shot).
## Empty: uses the running node's persistence_id + "_loot". If that is empty too, the flag
## only lasts while the player stays in the level.
@export var persistence_id: String = ""

@export_group("Spawn")
## Point the items drop from (e.g. a Marker2D), relative to the node running the action.
## Empty: that node's pivot (the enemy, the trigger...).
@export var spawn_at: NodePath = NodePath("")
@export var pickup_item_scene: PackedScene = preload("res://src/overworld/interactables/pickup_item.tscn")
## Maximum scatter radius so items don't pile up.
@export var scatter_radius: float = 24.0
## Time an item takes to land before it can be picked up.
@export var drop_duration: float = 0.45
## Staggered delay between items so they don't all drop at once.
@export var scatter_delay: float = 0.05

@export_group("Event (optional)")
## Global event fired if at least one item was dropped.
@export var on_dropped_event: String = ""

func get_action_name() -> String:
	return "DropLootAction (%d entries, max %d%s)" % [entries.size(), drop_count, ", once" if one_shot else ""]

func execute(trigger_node: Node) -> void:
	if trigger_node == null or not trigger_node.is_inside_tree():
		push_warning("DropLootAction: the running node is not in the scene tree.")
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

## Rolls the list and spawns the PickupItems. Returns the spawned items.
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
	# "unique_dropped" is the flag saved by the old LootDropComponent (old saves)
	return data.get("dropped", false) or data.get("unique_dropped", false)

func _spawn_origin(trigger_node: Node) -> Vector2:
	var at: Node = trigger_node.get_node_or_null(spawn_at) if not spawn_at.is_empty() else trigger_node
	if at is Node2D:
		return (at as Node2D).global_position
	if trigger_node is Node2D:
		return (trigger_node as Node2D).global_position
	return Vector2.ZERO

## Items go to the running node's parent (the level), so they survive if that node is freed.
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
