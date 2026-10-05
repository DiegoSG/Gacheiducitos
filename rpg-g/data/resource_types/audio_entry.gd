class_name AudioEntry
extends Resource

## Asocia un identificador de audio con su sonido. Si stream es null, el identificador
## existe pero todavía no tiene archivo asignado y AudioManager no reproduce nada.

@export var id: StringName = &""
@export var stream: AudioStream = null
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var volume_db: float = 0.0
