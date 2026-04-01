extends Resource
class_name ItemData

enum ItemType { CONSUMABLE, EQUIPMENT, QUEST, MATERIAL }
enum ShapeType { CIRCLE, RECTANGLE, CAPSULE }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

@export_group("Basic Info")
@export var id: String = "":
	set(new_value):
		id = new_value
		emit_changed()

@export var name: String = "New Item":
	set(new_value):
		name = new_value
		emit_changed()

@export var rarity: Rarity = Rarity.COMMON:
	set(new_value):
		rarity = new_value
		emit_changed()

@export var value: int = 0:
	set(new_value):
		value = new_value
		emit_changed()

@export var icon: Texture2D:
	set(new_value):
		icon = new_value
		emit_changed()

@export var description: String = "":
	set(new_value):
		description = new_value
		emit_changed()

@export var type: ItemType = ItemType.CONSUMABLE:
	set(new_value):
		type = new_value
		emit_changed()

@export var stackable: bool = true:
	set(new_value):
		stackable = new_value
		emit_changed()

@export_group("Visuals")
@export var item_scale: Vector2 = Vector2(1, 1):
	set(value):
		item_scale = value
		emit_changed()

@export_group("Collision Settings")
@export var collision_type: ShapeType = ShapeType.CIRCLE:
	set(value):
		collision_type = value
		emit_changed()

@export var circle_radius: float = 16.0:
	set(value):
		circle_radius = value
		emit_changed()

@export var rectangle_size: Vector2 = Vector2(32, 32):
	set(value):
		rectangle_size = value
		emit_changed()

@export var capsule_height: float = 30.0:
	set(value):
		capsule_height = value
		emit_changed()

@export var capsule_radius: float = 10.0:
	set(value):
		capsule_radius = value
		emit_changed()

@export var collision_offset: Vector2 = Vector2.ZERO:
	set(value):
		collision_offset = value
		emit_changed()
