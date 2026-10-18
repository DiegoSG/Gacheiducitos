class_name PlaySoundAction
extends ActionResource

## Action that plays a sound from the audio catalog (AudioManager).
## Compatible with the GameTrigger, DialogueEvent and OnEventListener pipeline.

enum SoundType { SFX, UI, MUSIC }

## Identifier in the catalog (data/audio/audio_catalog.tres).
@export var sound_id: StringName = &""
## SFX: game effect (cut when paused). UI: keeps playing when paused. MUSIC: changes the music.
@export var sound_type: SoundType = SoundType.SFX

func get_action_name() -> String:
	return "PlaySoundAction (%s)" % sound_id

func execute(_trigger_node: Node) -> void:
	if sound_id.is_empty():
		push_warning("PlaySoundAction: sound_id is empty.")
		finished.emit()
		return

	match sound_type:
		SoundType.SFX:
			AudioManager.play_sfx(sound_id)
		SoundType.UI:
			AudioManager.play_ui(sound_id)
		SoundType.MUSIC:
			AudioManager.play_music(sound_id)
	finished.emit()
