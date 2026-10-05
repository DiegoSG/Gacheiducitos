extends Node

## Reproduce música y efectos por identificador, buscándolos en el catálogo de audio.
## - Música: play_music / stop_music, con fundido entre pistas. Se atenúa mientras el juego está pausado.
## - Efectos de juego: play_sfx. Se cortan cuando el juego se pausa; si se piden con el juego ya
##   pausado (por ejemplo desde un diálogo), suenan como efecto de interfaz.
## - Efectos de interfaz: play_ui. Suenan también con el juego pausado (menús, inventario, diálogos).
## Un identificador sin sonido asignado no reproduce nada y avisa una sola vez por consola.
## El volumen de los buses Music y SFX se guarda en user://settings.cfg.

const CATALOG_PATH: String = "res://data/audio/audio_catalog.tres"
const SETTINGS_PATH: String = "user://settings.cfg"
const SETTINGS_SECTION: String = "audio"
const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"
const SFX_POOL_SIZE: int = 8
const UI_POOL_SIZE: int = 8
const DEFAULT_FADE_TIME: float = 0.5
const SILENT_DB: float = -80.0
## Atenuación de la música mientras el juego está pausado.
const PAUSE_DUCK_DB: float = -10.0
const PAUSE_DUCK_TIME: float = 0.2
## Índice del efecto Amplify del bus Music (definido en default_bus_layout.tres).
const MUSIC_DUCK_EFFECT_INDEX: int = 0

var _catalog: AudioCatalog = null
var _music_players: Array[AudioStreamPlayer] = []
var _active_music_index: int = 0
var _current_music_id: StringName = &""
var _music_tween: Tween = null
var _duck_tween: Tween = null
var _sfx_players: Array[AudioStreamPlayer] = []
var _ui_players: Array[AudioStreamPlayer] = []
var _warned_ids: Dictionary[StringName, bool] = {}
var _was_paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_catalog = load(CATALOG_PATH) as AudioCatalog
	if _catalog == null:
		push_error("[AudioManager] No se pudo cargar el catálogo: %s" % CATALOG_PATH)

	for i: int in 2:
		_music_players.append(_create_player(MUSIC_BUS, Node.PROCESS_MODE_ALWAYS))
	for i: int in SFX_POOL_SIZE:
		_sfx_players.append(_create_player(SFX_BUS, Node.PROCESS_MODE_PAUSABLE))
	for i: int in UI_POOL_SIZE:
		_ui_players.append(_create_player(SFX_BUS, Node.PROCESS_MODE_ALWAYS))

	load_settings()

# La pausa se detecta por sondeo porque varios sistemas cambian SceneTree.paused directamente.
func _process(_delta: float) -> void:
	var paused: bool = get_tree().paused
	if paused != _was_paused:
		_was_paused = paused
		_on_pause_changed(paused)

# --- Música ---

## Reproduce la música del identificador con fundido. Si ya está sonando, no la reinicia.
## Un identificador vacío o sin sonido asignado detiene la música actual.
func play_music(id: StringName, fade_time: float = DEFAULT_FADE_TIME) -> void:
	if id == _current_music_id:
		return
	_current_music_id = id
	var entry: AudioEntry = _get_playable_entry(id) if not id.is_empty() else null
	if entry == null:
		_fade_out_music(fade_time)
		return

	var old_player: AudioStreamPlayer = _music_players[_active_music_index]
	_active_music_index = 1 - _active_music_index
	var new_player: AudioStreamPlayer = _music_players[_active_music_index]
	new_player.stream = entry.stream
	new_player.volume_db = SILENT_DB
	new_player.play()

	_kill_tween(_music_tween)
	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_property(new_player, "volume_db", entry.volume_db, fade_time)
	if old_player.playing:
		_music_tween.tween_property(old_player, "volume_db", SILENT_DB, fade_time)
		_music_tween.chain().tween_callback(old_player.stop)

func stop_music(fade_time: float = DEFAULT_FADE_TIME) -> void:
	_current_music_id = &""
	_fade_out_music(fade_time)

func get_current_music_id() -> StringName:
	return _current_music_id

# --- Efectos ---

## Efecto de juego: se corta si el juego se pausa.
func play_sfx(id: StringName) -> void:
	_play_from_pool(id, _ui_players if get_tree().paused else _sfx_players)

## Efecto de interfaz: suena aunque el juego esté pausado.
func play_ui(id: StringName) -> void:
	_play_from_pool(id, _ui_players)

## Entrada con sonido asignado, para nodos que usan su propio reproductor (bucles o sonido
## posicional). Devuelve null si no hay sonido asignado.
func get_playable_entry(id: StringName) -> AudioEntry:
	return _get_playable_entry(id)

# --- Volumen ---

## Volumen lineal del bus (0.0 a 1.0).
func get_bus_volume(bus: StringName) -> float:
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0:
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(index))

func set_bus_volume(bus: StringName, linear: float) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0:
		push_warning("[AudioManager] No existe el bus: %s" % bus)
		return
	var clamped: float = clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(clamped))
	AudioServer.set_bus_mute(index, is_zero_approx(clamped))

func save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	# Se carga primero para no borrar otras secciones que se agreguen al archivo en el futuro.
	config.load(SETTINGS_PATH)
	config.set_value(SETTINGS_SECTION, String(MUSIC_BUS), get_bus_volume(MUSIC_BUS))
	config.set_value(SETTINGS_SECTION, String(SFX_BUS), get_bus_volume(SFX_BUS))
	var error: Error = config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("[AudioManager] No se pudo guardar %s (error %d)" % [SETTINGS_PATH, error])

func load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	for bus: StringName in [MUSIC_BUS, SFX_BUS]:
		var value: float = float(config.get_value(SETTINGS_SECTION, String(bus), 1.0))
		set_bus_volume(bus, value)

# --- Internos ---

func _create_player(bus: StringName, mode: Node.ProcessMode) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = bus
	player.process_mode = mode
	add_child(player)
	return player

func _play_from_pool(id: StringName, pool: Array[AudioStreamPlayer]) -> void:
	var entry: AudioEntry = _get_playable_entry(id)
	if entry == null:
		return
	var player: AudioStreamPlayer = _get_free_player(pool)
	player.stream = entry.stream
	player.volume_db = entry.volume_db
	player.play()

## Devuelve un reproductor libre; si todos están ocupados, reutiliza el primero.
func _get_free_player(pool: Array[AudioStreamPlayer]) -> AudioStreamPlayer:
	for player: AudioStreamPlayer in pool:
		if not player.playing:
			return player
	return pool[0]

## Devuelve la entrada si tiene sonido asignado. Avisa una sola vez por identificador.
func _get_playable_entry(id: StringName) -> AudioEntry:
	var entry: AudioEntry = _catalog.get_entry(id) if _catalog != null else null
	if entry == null:
		_warn_once(id, "[AudioManager] Identificador de audio no está en el catálogo: %s" % id)
		return null
	if entry.stream == null:
		_warn_once(id, "[AudioManager] Identificador sin sonido asignado: %s" % id)
		return null
	return entry

func _warn_once(id: StringName, message: String) -> void:
	if _warned_ids.has(id):
		return
	_warned_ids[id] = true
	push_warning(message)

func _fade_out_music(fade_time: float) -> void:
	_kill_tween(_music_tween)
	_music_tween = create_tween().set_parallel(true)
	for player: AudioStreamPlayer in _music_players:
		if player.playing:
			_music_tween.tween_property(player, "volume_db", SILENT_DB, fade_time)
	_music_tween.chain().tween_callback(_stop_music_players)

func _stop_music_players() -> void:
	for player: AudioStreamPlayer in _music_players:
		player.stop()

func _on_pause_changed(paused: bool) -> void:
	if paused:
		for player: AudioStreamPlayer in _sfx_players:
			player.stop()
	_set_music_duck(PAUSE_DUCK_DB if paused else 0.0)

func _set_music_duck(target_db: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(MUSIC_BUS)
	if bus_index < 0 or AudioServer.get_bus_effect_count(bus_index) <= MUSIC_DUCK_EFFECT_INDEX:
		return
	var amplify: AudioEffectAmplify = AudioServer.get_bus_effect(bus_index, MUSIC_DUCK_EFFECT_INDEX) as AudioEffectAmplify
	if amplify == null:
		return
	_kill_tween(_duck_tween)
	_duck_tween = create_tween()
	_duck_tween.tween_property(amplify, "volume_db", target_db, PAUSE_DUCK_TIME)

func _kill_tween(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
