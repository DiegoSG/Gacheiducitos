extends Control

## Escena de prueba de AudioManager. Asigna tonos generados en memoria a algunos IDs
## (no modifica el catálogo en disco) y ofrece botones para música, efectos, pausa y volumen.

const TONE_MIX_RATE: int = 22050
const MUSIC_A_ID: StringName = &"music_level_01"
const MUSIC_B_ID: StringName = &"music_level_02"
const SFX_ID: StringName = &"sfx_player_attack"
const UI_ID: StringName = &"sfx_ui_confirm"
## Está en el catálogo pero sin sonido: debe quedar en silencio y avisar una vez por consola.
const UNASSIGNED_ID: StringName = &"sfx_chest_open"
## No está en el catálogo: debe quedar en silencio y avisar una vez por consola.
const UNKNOWN_ID: StringName = &"sfx_no_existe"

@onready var _buttons: VBoxContainer = %Buttons
@onready var _status_label: Label = %StatusLabel

var _paused: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_assign_test_tone(MUSIC_A_ID, 220.0, 2.0, true)
	_assign_test_tone(MUSIC_B_ID, 330.0, 2.0, true)
	_assign_test_tone(SFX_ID, 880.0, 0.6, false)
	_assign_test_tone(UI_ID, 1320.0, 0.15, false)

	_add_button("Música A", func() -> void: AudioManager.play_music(MUSIC_A_ID))
	_add_button("Música B (fundido)", func() -> void: AudioManager.play_music(MUSIC_B_ID))
	_add_button("Detener música", func() -> void: AudioManager.stop_music())
	_add_button("Efecto de juego (se corta en pausa)", func() -> void: AudioManager.play_sfx(SFX_ID))
	_add_button("Efecto de interfaz (suena en pausa)", func() -> void: AudioManager.play_ui(UI_ID))
	_add_button("ID sin sonido asignado", func() -> void: AudioManager.play_sfx(UNASSIGNED_ID))
	_add_button("ID inexistente", func() -> void: AudioManager.play_sfx(UNKNOWN_ID))
	_add_button("Pausar / reanudar", _toggle_pause)
	_add_slider("Música", AudioManager.MUSIC_BUS)
	_add_slider("Efectos", AudioManager.SFX_BUS)
	_add_button("Guardar volumen", func() -> void: AudioManager.save_settings())
	_update_status()

func _process(_delta: float) -> void:
	_update_status()

func _toggle_pause() -> void:
	_paused = not _paused
	if _paused:
		GameManager.request_pause()
	else:
		GameManager.release_pause()

func _update_status() -> void:
	_status_label.text = "Música: %s | Pausa: %s" % [AudioManager.get_current_music_id(), get_tree().paused]

func _add_button(text: String, action: Callable) -> void:
	var button: Button = Button.new()
	button.text = text
	button.pressed.connect(action)
	_buttons.add_child(button)

func _add_slider(text: String, bus: StringName) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(80, 0)
	var slider: HSlider = HSlider.new()
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = AudioManager.get_bus_volume(bus)
	slider.custom_minimum_size = Vector2(200, 0)
	slider.value_changed.connect(func(value: float) -> void: AudioManager.set_bus_volume(bus, value))
	row.add_child(label)
	row.add_child(slider)
	_buttons.add_child(row)

## Asigna en memoria un tono senoidal a la entrada del catálogo.
func _assign_test_tone(id: StringName, frequency: float, duration: float, loop: bool) -> void:
	var catalog: AudioCatalog = load(AudioManager.CATALOG_PATH) as AudioCatalog
	var entry: AudioEntry = catalog.get_entry(id) if catalog != null else null
	if entry == null:
		push_error("test_audio: falta el ID en el catálogo: %s" % id)
		return
	entry.stream = _make_tone(frequency, duration, loop)

func _make_tone(frequency: float, duration: float, loop: bool) -> AudioStreamWAV:
	var sample_count: int = int(TONE_MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	for i: int in sample_count:
		var sample: float = sin(TAU * frequency * float(i) / TONE_MIX_RATE) * 0.3
		data.encode_s16(i * 2, int(sample * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = TONE_MIX_RATE
	stream.stereo = false
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = sample_count
	return stream
