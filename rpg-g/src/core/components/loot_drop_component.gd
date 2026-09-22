@tool
extends Node2D
class_name LootDropComponent

## Emitted when loot has been calculated and spawned in the world
signal loot_dropped(dropped_pickups: Array[PickupItem])

@export_group("One-Time Drop (Único)")
## Ítem especial que solo se suelta una única vez en la partida
@export var unique_item: ItemData = null
## Probabilidad del ítem único del 0 al 10 (10 = 100% garantizado en su primera muerte)
@export_range(0, 10) var unique_probability: int = 10
## ID de persistencia para WorldStateManager.
## Si tiene un valor asignado, la entrega del drop único se guarda para siempre.
## Si está vacío (""), no hay persistencia y se recalcula cada vez.
@export var persistence_id: String = ""

@export_group("Standard Loot Table")
## Tabla de loot: Clave = Ítem (ItemData), Valor = Probabilidad de 0 a 10 (10 = 100%)
@export var loot_table: Dictionary[ItemData, int] = {}
## Cantidad máxima de ítems de la lista que soltará al morir
@export_range(1, 10) var drop_count: int = 1

@export_group("Coins")
## Activar o desactivar drop de monedas
@export var enable_coins: bool = true
## Cantidad mínima de monedas a soltar
@export var min_coins: int = 0
## Cantidad máxima de monedas a soltar
@export var max_coins: int = 5

@export_group("Spawn Settings")
@export var pickup_item_scene: PackedScene = preload("res://src/overworld/interactables/pickup_item.tscn")
@export var coin_item_data: ItemData = preload("res://data/items/gold_coins.tres")
## Radio máximo de dispersión física para que los objetos no se amontonen
@export var scatter_radius: float = 24.0
## Tiempo que tarda el objeto en caer a su posición final antes de ser recolectable
@export var drop_duration: float = 0.45
## Micro-retraso escalonado entre drops para que no salgan exactamente al mismo tiempo
@export var scatter_delay: float = 0.05

var _has_dropped_unique: bool = false

func _ready() -> void:
	if persistence_id.is_empty():
		persistence_id = "ephemeral_" + str(owner.get_path_to(self)) if owner else str(get_path()) + "_ephemeral"
	if Engine.is_editor_hint():
		return
	if not persistence_id.is_empty():
		var wsm = _get_world_state_manager()
		if wsm and wsm.has_state(persistence_id):
			_has_dropped_unique = wsm.load_state(persistence_id).get("unique_dropped", false)

## Ejecuta la lógica completa de loot y spawnea los objetos en el nivel.
func drop_loot(spawn_pos: Vector2 = global_position) -> Array[PickupItem]:
	if Engine.is_editor_hint():
		return []
	var spawned_pickups: Array[PickupItem] = []
	var drop_index: int = 0
	
	# 1. Procesar Ítem Único (One-Time Drop)
	if unique_item and not _is_unique_already_dropped():
		if _roll_probability(unique_probability):
			var unique_pickup = _spawn_pickup(unique_item, -1, spawn_pos, drop_index)
			if unique_pickup:
				spawned_pickups.append(unique_pickup)
				drop_index += 1
			_mark_unique_as_dropped()
	
	# 2. Procesar Tabla de Loot Estándar
	var candidates: Array[ItemData] = []
	for item in loot_table:
		var prob: int = loot_table[item]
		if item and prob > 0:
			if _roll_probability(prob):
				candidates.append(item)
	
	# Si hay más candidatos exitosos que drop_count, mezclamos y tomamos hasta drop_count
	if not candidates.is_empty():
		candidates.shuffle()
		var count_to_spawn: int = mini(drop_count, candidates.size())
		for i in range(count_to_spawn):
			var pickup = _spawn_pickup(candidates[i], -1, spawn_pos, drop_index)
			if pickup:
				spawned_pickups.append(pickup)
				drop_index += 1
	
	# 3. Procesar Monedas
	if enable_coins and max_coins > 0 and coin_item_data:
		var coins_amount: int = randi_range(min_coins, max_coins)
		if coins_amount > 0:
			var coin_pickup = _spawn_pickup(coin_item_data, coins_amount, spawn_pos, drop_index)
			if coin_pickup:
				spawned_pickups.append(coin_pickup)
				drop_index += 1
				
	loot_dropped.emit(spawned_pickups)
	return spawned_pickups

## Evalúa una probabilidad en escala 0 a 10 (0 = nunca / 0%, 10 = siempre / 100%)
func _roll_probability(prob_rating: int) -> bool:
	if prob_rating <= 0:
		return false
	if prob_rating >= 10:
		return true
	
	var roll: int = randi_range(1, 10)
	return roll <= prob_rating

func _is_unique_already_dropped() -> bool:
	if not persistence_id.is_empty():
		var wsm = _get_world_state_manager()
		if wsm and wsm.has_state(persistence_id):
			return wsm.load_state(persistence_id).get("unique_dropped", false)
	return _has_dropped_unique

func _mark_unique_as_dropped() -> void:
	_has_dropped_unique = true
	if not persistence_id.is_empty():
		var wsm = _get_world_state_manager()
		if wsm:
			wsm.save_state(persistence_id, {"unique_dropped": true})

func _get_world_state_manager() -> Node:
	return WorldStateManager

## Instancia el PickupItem en la escena con animación cinemática radial (Tween)
func _spawn_pickup(item_res: ItemData, custom_amount: int, origin_pos: Vector2, delay_step: int = 0) -> PickupItem:
	if not pickup_item_scene or not item_res:
		return null
		
	var target_parent: Node = _find_spawn_parent()
	if not target_parent:
		return null
		
	var pickup = pickup_item_scene.instantiate() as PickupItem
	if not pickup:
		return null
		
	pickup.item_data = item_res
	if custom_amount > 0:
		pickup.custom_amount = custom_amount
		
	# Offset aleatorio para que los drops no queden perfectamente alineados
	var angle: float = randf() * TAU
	var distance: float = randf_range(12.0, scatter_radius)
	var target_pos: Vector2 = origin_pos + Vector2(cos(angle), sin(angle)) * distance
	
	# Iniciar animación de drop con delay escalonado y duración configurable
	var effective_duration: float = drop_duration + (float(delay_step) * scatter_delay)
	pickup.animate_drop_from(origin_pos, target_pos, effective_duration)
	
	target_parent.call_deferred("add_child", pickup)
	return pickup

func _find_spawn_parent() -> Node:
	# Prioridad: 1. Padre del dueño (el nivel), 2. Nivel padre, 3. current_scene, 4. get_parent()
	if owner and owner.get_parent():
		return owner.get_parent()
	if get_parent() and get_parent().get_parent():
		return get_parent().get_parent()
	if get_tree() and get_tree().current_scene:
		return get_tree().current_scene
	if get_parent():
		return get_parent()
	return self
