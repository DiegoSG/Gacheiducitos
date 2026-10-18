extends Resource
class_name StatusEffectData

## Definition of a status effect (poison, speed boost, etc.) that PlayerStats applies to the player.
## Reapplying an active status effect resets its duration.

@export var id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D
## Color the HUD tints health with while the status effect is active.
@export var hud_color: Color = Color(0.6, 0.2, 0.8, 1.0)
## Duration in seconds. 0 = permanent until cured.
@export var duration: float = 0.0

@export_group("Modifiers")
@export var speed_multiplier: float = 1.0
## Strength bonus (attack damage). Can be negative.
@export var strength_bonus: int = 0
@export var resistance_bonus: int = 0
@export var max_health_bonus: int = 0

@export_group("Periodic Effect")
## Seconds between ticks. 0 = no tick.
@export var tick_interval: float = 0.0
## Health per tick: negative = damage, positive = regeneration.
@export var health_per_tick: int = 0
## If false, tick damage never reduces health below 1.
@export var can_kill: bool = true
