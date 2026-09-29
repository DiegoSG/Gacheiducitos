extends Resource
class_name StatusEffectData

## Definicion de un estado alterado (veneno, aceleracion, etc.) que PlayerStats aplica al jugador.
## Reaplicar un estado activo reinicia su duracion.

@export var id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D
## Color con el que el HUD tine la vida mientras el estado esta activo.
@export var hud_color: Color = Color(0.6, 0.2, 0.8, 1.0)
## Duracion en segundos. 0 = permanente hasta curarlo.
@export var duration: float = 0.0

@export_group("Modificadores")
@export var speed_multiplier: float = 1.0
## Bonus a la fuerza (dano de ataque). Puede ser negativo.
@export var strength_bonus: int = 0
@export var resistance_bonus: int = 0
@export var max_health_bonus: int = 0

@export_group("Efecto periodico")
## Segundos entre ticks. 0 = sin tick.
@export var tick_interval: float = 0.0
## Vida por tick: negativo = dano, positivo = regeneracion.
@export var health_per_tick: int = 0
## Si es false, el dano del tick nunca baja la vida de 1.
@export var can_kill: bool = true
