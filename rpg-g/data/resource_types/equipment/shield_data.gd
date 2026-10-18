extends EquipmentData
class_name ShieldData

## Shield: what part of the damage it blocks, from which angle, and which statuses it stops.

## Percentage of the damage a hit blocks within the covered angle.
@export_range(0.0, 100.0, 1.0, "suffix:%") var block_percent: float = 100.0
## Coverage arc, centered on the direction the owner faces (360 = all directions).
@export_range(10.0, 360.0, 1.0, "suffix:°") var coverage_angle: float = 120.0
## Movement speed multiplier while blocking (0 = only turn).
@export_range(0.0, 1.0, 0.05) var move_speed_multiplier: float = 0.0
## Whether it protects from status effects on the hits it covers.
@export var blocks_statuses: bool = true
## Statuses it blocks (empty = all, if blocks_statuses is on).
@export var blocked_status_ids: Array[String] = []

func _init() -> void:
	kind = Kind.SHIELD

func blocks_status(status_id: String) -> bool:
	if not blocks_statuses:
		return false
	return blocked_status_ids.is_empty() or blocked_status_ids.has(status_id)
