class_name AudioEntry
extends Resource

## Maps an audio identifier to its sound. If stream is null, the identifier
## exists but has no file assigned yet, and AudioManager plays nothing.

@export var id: StringName = &""
@export var stream: AudioStream = null
@export_range(-40.0, 12.0, 0.5, "suffix:dB") var volume_db: float = 0.0
## Random pitch variation on each playback (0.1 = ±10%). 0 = always the same.
@export_range(0.0, 0.5, 0.01) var pitch_random: float = 0.0
## Minimum time between two playbacks of the same identifier. 0 = no limit.
@export_range(0.0, 2.0, 0.01, "suffix:s") var cooldown: float = 0.0
