@tool
extends Area2D
class_name PickupItem

@export_group("Item Data")
@export var item_data: ItemData:
	set(value):
		if item_data and item_data.changed.is_connected(_sync_with_resource):
			item_data.changed.disconnect(_sync_with_resource)
			
		item_data = value
		
		if item_data:
			if not item_data.changed.is_connected(_sync_with_resource):
				item_data.changed.connect(_sync_with_resource)
			_sync_with_resource()
		else:
			_clear_visuals()

@export var custom_amount: int = -1
@export var drop_animation_duration: float = 0.45

@export_group("Persistencia")
@export var persistence_id: String = ""

## Control para evitar recolección instantánea mientras el objeto cae/se anima
var can_be_collected: bool = true
var _pending_start_pos: Vector2 = Vector2.INF
var _pending_target_pos: Vector2 = Vector2.INF
var _pending_duration: float = 0.45
var _persistence_key: String = ""

# Internal state (not exported)
var _item_icon: Texture2D
var _item_scale: Vector2 = Vector2(0.3, 0.3)
var _collision_type: ItemData.ShapeType = ItemData.ShapeType.CIRCLE
var _circle_radius: float = 16.0
var _rectangle_size: Vector2 = Vector2(32, 32)
var _capsule_height: float = 30.0
var _capsule_radius: float = 10.0
var _collision_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	_persistence_key = PersistenceIdHelper.runtime_key(self, persistence_id)
	if item_data:
		if not item_data.changed.is_connected(_sync_with_resource):
			item_data.changed.connect(_sync_with_resource)
		_sync_with_resource()
	
	_update_visuals()
	_update_collision_shape()
	
	if not Engine.is_editor_hint():
		# Restaurar estado: si ya fue recolectado, eliminar inmediatamente
		if _is_already_collected():
			queue_free()
			return
		if not body_entered.is_connected(_on_body_entered):
			body_entered.connect(_on_body_entered)
			
	if _pending_start_pos != Vector2.INF and not Engine.is_editor_hint():
		_start_drop_tween(_pending_start_pos, _pending_target_pos, _pending_duration)
		_pending_start_pos = Vector2.INF
		_pending_target_pos = Vector2.INF

func _sync_with_resource() -> void:
	if not item_data: return
	
	_item_icon = item_data.icon
	_item_scale = item_data.item_scale
	_collision_type = item_data.collision_type
	_circle_radius = item_data.circle_radius
	_rectangle_size = item_data.rectangle_size
	_capsule_height = item_data.capsule_height
	_capsule_radius = item_data.capsule_radius
	_collision_offset = item_data.collision_offset
	
	if is_inside_tree():
		_update_visuals()
		_update_collision_shape()

func _clear_visuals() -> void:
	var sprite: Sprite2D = get_node_or_null("Sprite2D")
	if sprite:
		sprite.texture = null
	var col_shape_node: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if col_shape_node:
		col_shape_node.shape = null

func _update_visuals() -> void:
	var sprite: Sprite2D = get_node_or_null("Sprite2D")
	if sprite:
		sprite.texture = _item_icon
		sprite.scale = _item_scale

func _update_collision_shape() -> void:
	var col_shape_node: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if not col_shape_node: return
	
	col_shape_node.position = _collision_offset
		
	match _collision_type:
		ItemData.ShapeType.CIRCLE:
			if col_shape_node.shape is CircleShape2D:
				(col_shape_node.shape as CircleShape2D).radius = _circle_radius
			else:
				var shape: CircleShape2D = CircleShape2D.new()
				shape.radius = _circle_radius
				col_shape_node.shape = shape
		ItemData.ShapeType.RECTANGLE:
			if col_shape_node.shape is RectangleShape2D:
				(col_shape_node.shape as RectangleShape2D).size = _rectangle_size
			else:
				var shape: RectangleShape2D = RectangleShape2D.new()
				shape.size = _rectangle_size
				col_shape_node.shape = shape
		ItemData.ShapeType.CAPSULE:
			if col_shape_node.shape is CapsuleShape2D:
				var cap: CapsuleShape2D = col_shape_node.shape as CapsuleShape2D
				cap.radius = _capsule_radius
				cap.height = _capsule_height
			else:
				var shape: CapsuleShape2D = CapsuleShape2D.new()
				shape.radius = _capsule_radius
				shape.height = _capsule_height
				col_shape_node.shape = shape

func _on_body_entered(body: Node2D) -> void:
	if Engine.is_editor_hint(): return
	if not item_data: return
	if not can_be_collected: return
	
	if body.is_in_group("player") or body.name == "Player":
		# El oro usa el valor del recurso por defecto; el resto de ítems, 1 unidad
		var default_amount: int = item_data.value if item_data.id == Inventory.GOLD_ITEM_ID else 1
		var qty: int = custom_amount if custom_amount > 0 else default_amount
		Inventory.add_item(item_data.id, qty)
		AudioManager.play_sfx(&"sfx_pickup_gold" if item_data.id == Inventory.GOLD_ITEM_ID else &"sfx_pickup_item")
		LootFeedbackManager.trigger_toast(item_data, qty)
		
		_persist_collected()
		queue_free()

## Inicia una animación matemática (Tween) estilo drop cinematográfico sin físicas
func animate_drop_from(start_pos: Vector2, target_pos: Vector2, duration: float = -1.0) -> void:
	can_be_collected = false
	var anim_duration: float = duration if duration > 0.0 else drop_animation_duration
	if not is_inside_tree():
		_pending_start_pos = start_pos
		_pending_target_pos = target_pos
		_pending_duration = anim_duration
		global_position = start_pos
		return
		
	_start_drop_tween(start_pos, target_pos, anim_duration)

func _start_drop_tween(start_pos: Vector2, target_pos: Vector2, duration: float) -> void:
	can_be_collected = false
	global_position = start_pos
	
	var sprite: Sprite2D = get_node_or_null("Sprite2D")
	var original_sprite_pos_y: float = sprite.position.y if sprite else 0.0
	var final_scale: Vector2 = _item_scale
	
	if sprite:
		sprite.scale = Vector2.ZERO
		sprite.modulate.a = 0.0
	
	var tween: Tween = create_tween().set_parallel(true)
	
	# 1. Desplazamiento en X/Y hacia la posición de destino
	tween.tween_property(self, "global_position", target_pos, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	if sprite:
		# 2. Fade in rápido al aparecer
		tween.tween_property(sprite, "modulate:a", 1.0, duration * 0.25)
		
		# 3. Pop-in de escala: 0 -> ligeramente aumentado (1.15x) -> tamaño normal
		var scale_tween: Tween = create_tween()
		scale_tween.tween_property(sprite, "scale", final_scale * 1.15, duration * 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		scale_tween.tween_property(sprite, "scale", final_scale, duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		
		# 4. Arco parabólico y rebote
		var jump_height: float = 20.0
		var jump_tween: Tween = create_tween()
		jump_tween.tween_property(sprite, "position:y", original_sprite_pos_y - jump_height, duration * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		jump_tween.tween_property(sprite, "position:y", original_sprite_pos_y, duration * 0.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		
	tween.finished.connect(_on_drop_animation_finished)

func _on_drop_animation_finished() -> void:
	can_be_collected = true
	AudioManager.play_sfx(&"sfx_loot_land")
	var sprite: Sprite2D = get_node_or_null("Sprite2D")
	if sprite:
		sprite.scale = _item_scale
		sprite.modulate.a = 1.0
	# Si el jugador ya estaba encima al aterrizar, se recoge automáticamente
	if not Engine.is_editor_hint() and is_inside_tree():
		for body in get_overlapping_bodies():
			if body.is_in_group("player") or body.name == "Player":
				_on_body_entered(body)
				break

func _is_already_collected() -> bool:
	if _persistence_key.is_empty():
		return false
	if WorldStateManager.has_state(_persistence_key):
		var data: Dictionary = WorldStateManager.load_state(_persistence_key)
		return data.get("is_collected", false)
	return false

func _persist_collected() -> void:
	if _persistence_key.is_empty():
		return
	WorldStateManager.save_state(_persistence_key, {"is_collected": true})
