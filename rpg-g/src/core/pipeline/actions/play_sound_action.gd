class_name PlaySoundAction
extends ActionResource

## Acción que reproduce un sonido del catálogo de audio (AudioManager).
## Compatible con el pipeline de GameTrigger, DialogueEvent y OnEventListener.

enum SoundType { SFX, UI, MUSIC }

## Identificador del catálogo (data/audio/audio_catalog.tres).
@export var sound_id: StringName = &""
## SFX: efecto de juego (se corta en pausa). UI: suena en pausa. MUSIC: cambia la música.
@export var sound_type: SoundType = SoundType.SFX

func get_action_name() -> String:
	return "PlaySoundAction (%s)" % sound_id

func execute(_trigger_node: Node) -> void:
	if sound_id.is_empty():
		push_warning("PlaySoundAction: sound_id está vacío.")
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
