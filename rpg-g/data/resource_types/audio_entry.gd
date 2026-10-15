class_name AudioEntry
extends Resource

## Asocia un identificador de audio con su sonido. Si stream es null, el identificador
## existe pero todavía no tiene archivo asignado y AudioManager no reproduce nada.

@export var id: StringName = &""
@export var stream: AudioStream = null
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var volume_db: float = 0.0
## Variación aleatoria del tono en cada reproducción (0.1 = ±10%). 0 = siempre igual.
@export_range(0.0, 0.5, 0.01) var pitch_random: float = 0.0
## Tiempo mínimo entre dos reproducciones del mismo identificador. 0 = sin límite.
@export_range(0.0, 2.0, 0.01, "suffix:s") var cooldown: float = 0.0
