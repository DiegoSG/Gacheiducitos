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

@export_group("Consumable Effects")
@export var heal_amount: int = 0:
	set(new_value):
		heal_amount = new_value
		emit_changed()

@export var damage_amount: int = 0:
	set(new_value):
		damage_amount = new_value
		emit_changed()

@export_group("Visuals")
@export var item_scale: Vector2 = Vector2(1, 1):
	set(new_value):
		item_scale = new_value
		emit_changed()

@export_group("Collision Settings")
@export var collision_type: ShapeType = ShapeType.CIRCLE:
	set(new_value):
		collision_type = new_value
		emit_changed()

@export var circle_radius: float = 16.0:
	set(new_value):
		circle_radius = new_value
		emit_changed()

@export var rectangle_size: Vector2 = Vector2(32, 32):
	set(new_value):
		rectangle_size = new_value
		emit_changed()

@export var capsule_height: float = 30.0:
	set(new_value):
		capsule_height = new_value
		emit_changed()

@export var capsule_radius: float = 10.0:
	set(new_value):
		capsule_radius = new_value
		emit_changed()

@export var collision_offset: Vector2 = Vector2.ZERO:
	set(new_value):
		collision_offset = new_value
		emit_changed()
