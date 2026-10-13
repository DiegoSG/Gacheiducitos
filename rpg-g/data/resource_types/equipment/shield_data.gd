extends EquipmentData
class_name ShieldData

## Escudo: qué parte del daño bloquea, desde qué ángulo y qué estados detiene.

## Porcentaje del daño que bloquea un golpe dentro del ángulo cubierto.
@export_range(0.0, 100.0, 1.0, "suffix:%") var block_percent: float = 100.0
## Apertura de la cobertura, centrada en la dirección que mira el dueño (360 = todas las direcciones).
@export_range(10.0, 360.0, 1.0, "suffix:°") var coverage_angle: float = 120.0
## Multiplicador de velocidad mientras se bloquea (0 = solo girar).
@export_range(0.0, 1.0, 0.05) var move_speed_multiplier: float = 0.0
## Si protege de estados alterados en los golpes que cubre.
@export var blocks_statuses: bool = true
## Estados que bloquea (vacío = todos, si blocks_statuses está activo).
@export var blocked_status_ids: Array[String] = []

func _init() -> void:
	kind = Kind.SHIELD

func blocks_status(status_id: String) -> bool:
	if not blocks_statuses:
		return false
	return blocked_status_ids.is_empty() or blocked_status_ids.has(status_id)
