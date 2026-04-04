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
	if item_data:
		if not item_data.changed.is_connected(_sync_with_resource):
			item_data.changed.connect(_sync_with_resource)
		_sync_with_resource()
	
	_update_visuals()
	_update_collision_shape()
	
	if not Engine.is_editor_hint():
		if not body_entered.is_connected(_on_body_entered):
			body_entered.connect(_on_body_entered)

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
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		sprite.texture = null
	var col_shape_node = get_node_or_null("CollisionShape2D")
	if col_shape_node:
		col_shape_node.shape = null

func _update_visuals() -> void:
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		sprite.texture = _item_icon
		sprite.scale = _item_scale

func _update_collision_shape() -> void:
	var col_shape_node = get_node_or_null("CollisionShape2D")
	if not col_shape_node: return
	
	col_shape_node.position = _collision_offset
		
	match _collision_type:
		ItemData.ShapeType.CIRCLE:
			var shape = CircleShape2D.new()
			shape.radius = _circle_radius
			col_shape_node.shape = shape
		ItemData.ShapeType.RECTANGLE:
			var shape = RectangleShape2D.new()
			shape.size = _rectangle_size
			col_shape_node.shape = shape
		ItemData.ShapeType.CAPSULE:
			var shape = CapsuleShape2D.new()
			shape.radius = _capsule_radius
			shape.height = _capsule_height
			col_shape_node.shape = shape

func _on_body_entered(body: Node2D) -> void:
	if Engine.is_editor_hint(): return
	if not item_data: return
	
	if body.is_in_group("player") or body.name == "Player":
		if item_data.id == "gold_coins":
			PlayerStats.add_gold(item_data.value)
		else:
			var inventory = get_node_or_null("/root/Inventory")
			if inventory:
				inventory.add_item(item_data.id)
		
		queue_free()
