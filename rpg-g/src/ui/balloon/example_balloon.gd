extends CanvasLayer
## A basic dialogue balloon for use with Dialogue Manager.


## The dialogue resource
@export var dialogue_resource: DialogueResource

## Start from a given title when using balloon as a [Node] in a scene.
@export var start_from_title: String = ""

## If running as a [Node] in a scene then auto start the dialogue.
@export var auto_start: bool = false

## If all other input is blocked as long as dialogue is shown.
@export var will_block_other_input: bool = true

## Acción para completar el texto que se está escribiendo y, ya completo, avanzar de línea
@export var next_action: StringName = &"ui_accept"

## Acción para completar el texto que se está escribiendo (misma que next_action; ui_cancel queda libre como Atrás)
@export var skip_action: StringName = &"ui_accept"

## Acción de avance rápido: salta líneas hasta la próxima decisión (respuestas) o el final del diálogo
@export var fast_forward_action: StringName = &"fast_forward"

## Máximo de líneas que el avance rápido recorre de una vez (evita bucles infinitos)
@export var fast_forward_max_lines: int = 256

## Segundos mínimos entre dos sonidos de letra del texto escribiéndose
const TYPE_SOUND_INTERVAL: float = 0.05

## Frames de gracia tras abrir el diálogo en los que se ignora el input (evita que la pulsación que lo abrió avance la primera línea)
@export var open_input_grace_frames: int = 2

## A sound player for voice lines (if they exist).
@onready var audio_stream_player: AudioStreamPlayer = %AudioStreamPlayer

## Temporary game states
var temporary_game_states: Array = []

## See if we are waiting for the player
var is_waiting_for_input: bool = false

## See if we are running a long mutation and should hide the balloon
var will_hide_balloon: bool = false

## A dictionary to store any ephemeral variables
var locals: Dictionary = {}

## Frame del proceso a partir del cual se acepta input
var _input_unlock_frame: int = 0

## Evita reentradas mientras corre el avance rápido
var _is_fast_forwarding: bool = false

## Segundos que faltan para permitir el siguiente sonido de letra
var _type_sound_cooldown: float = 0.0

var _locale: String = TranslationServer.get_locale()

## The current line
var dialogue_line: DialogueLine:
	set(value):
		if value:
			dialogue_line = value
			apply_dialogue_line()
		else:
			# The dialogue has finished so close the balloon
			if owner == null:
				queue_free()
			else:
				hide()
	get:
		return dialogue_line

## A cooldown timer for delaying the balloon hide when encountering a mutation.
var mutation_cooldown: Timer = Timer.new()

## The base balloon anchor
@onready var balloon: Control = %Balloon

## The label showing the name of the currently speaking character
@onready var character_label: RichTextLabel = %CharacterLabel

## The label showing the currently spoken dialogue
@onready var dialogue_label: DialogueLabel = %DialogueLabel

## The menu of responses
@onready var responses_menu: DialogueResponsesMenu = %ResponsesMenu

## Indicator to show that player can progress dialogue.
@onready var progress: Polygon2D = %Progress


func _ready() -> void:
	# El juego se pausa durante los diálogos; el globo debe seguir funcionando
	process_mode = Node.PROCESS_MODE_ALWAYS
	balloon.hide()
	DialogueManager.mutated.connect(_on_mutated)
	dialogue_label.spoke.connect(_on_dialogue_label_spoke)
	responses_menu.response_focused.connect(_on_responses_menu_response_focused)

	# If the responses menu doesn't have a next action set, use this one
	if responses_menu.next_action.is_empty():
		responses_menu.next_action = next_action

	mutation_cooldown.timeout.connect(_on_mutation_cooldown_timeout)
	add_child(mutation_cooldown)

	_input_unlock_frame = Engine.get_process_frames() + open_input_grace_frames
	if auto_start:
		if not is_instance_valid(dialogue_resource):
			assert(false, DMConstants.get_error_message(DMConstants.ERR_MISSING_RESOURCE_FOR_AUTOSTART))
		start()


func _process(delta: float) -> void:
	_type_sound_cooldown = maxf(0.0, _type_sound_cooldown - delta)
	if is_instance_valid(dialogue_line):
		progress.visible = not dialogue_label.is_typing and dialogue_line.responses.size() == 0 and not dialogue_line.has_tag("voice")


func _unhandled_input(_event: InputEvent) -> void:
	# Only the balloon is allowed to handle input while it's showing
	if will_block_other_input:
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	## Detect a change of locale and update the current dialogue line to show the new language
	if what == NOTIFICATION_TRANSLATION_CHANGED and _locale != TranslationServer.get_locale() and is_instance_valid(dialogue_label):
		_locale = TranslationServer.get_locale()
		var visible_ratio: float = dialogue_label.visible_ratio
		dialogue_line = await dialogue_resource.get_next_dialogue_line(dialogue_line.id)
		if visible_ratio < 1:
			dialogue_label.skip_typing()


## Start some dialogue
func start(with_dialogue_resource: DialogueResource = null, title: String = "", extra_game_states: Array = []) -> void:
	temporary_game_states = [self] + extra_game_states
	is_waiting_for_input = false
	_input_unlock_frame = Engine.get_process_frames() + open_input_grace_frames
	if is_instance_valid(with_dialogue_resource):
		dialogue_resource = with_dialogue_resource
	if not title.is_empty():
		start_from_title = title
	dialogue_line = await dialogue_resource.get_next_dialogue_line(start_from_title, temporary_game_states)
	show()
	AudioManager.play_ui(&"sfx_dialogue_open")


## Apply any changes to the balloon given a new [DialogueLine].
func apply_dialogue_line() -> void:
	mutation_cooldown.stop()
	var current_line: DialogueLine = dialogue_line

	progress.hide()
	is_waiting_for_input = false
	balloon.focus_mode = Control.FOCUS_ALL
	balloon.grab_focus()

	character_label.visible = not dialogue_line.character.is_empty()
	character_label.text = tr(dialogue_line.character, "dialogue")

	dialogue_label.hide()
	dialogue_label.dialogue_line = dialogue_line

	responses_menu.hide()
	responses_menu.responses = dialogue_line.responses
	

	# Show our balloon

	balloon.show()
	will_hide_balloon = false

	dialogue_label.show()
	if not dialogue_line.text.is_empty():
		dialogue_label.type_out()
		await dialogue_label.finished_typing
		# Si mientras tanto se cambió de línea (p. ej. avance rápido), no seguir con esta
		if dialogue_line != current_line: return
		AudioManager.play_ui(&"sfx_dialogue_line_done")

	# Wait for next line
	if dialogue_line.has_tag("voice"):
		AudioManager.play_ui(&"sfx_dialogue_voice")
		audio_stream_player.stream = load(dialogue_line.get_tag_value("voice"))
		audio_stream_player.play()
		await audio_stream_player.finished
		if dialogue_line != current_line: return
		next(dialogue_line.next_id)
	elif dialogue_line.responses.size() > 0:
		balloon.focus_mode = Control.FOCUS_NONE
		responses_menu.show()
		AudioManager.play_ui(&"sfx_dialogue_responses_shown")
	elif dialogue_line.time != "":
		var time: float = dialogue_line.text.length() * 0.02 if dialogue_line.time == "auto" else dialogue_line.time.to_float()
		await get_tree().create_timer(time).timeout
		if dialogue_line != current_line: return
		next(dialogue_line.next_id)
	else:
		is_waiting_for_input = true
		balloon.focus_mode = Control.FOCUS_ALL
		balloon.grab_focus()
		AudioManager.play_ui(&"sfx_dialogue_continue_shown")


## Go to the next line
func next(next_id: String) -> void:
	dialogue_line = await dialogue_resource.get_next_dialogue_line(next_id, temporary_game_states)


## Avance rápido: recorre las líneas (ejecutando sus mutaciones) hasta la próxima línea con
## respuestas o el final del diálogo. Nunca salta una decisión del jugador.
func fast_forward() -> void:
	if _is_fast_forwarding or not is_instance_valid(dialogue_line): return
	_is_fast_forwarding = true
	is_waiting_for_input = false
	AudioManager.play_ui(&"sfx_dialogue_fast_forward")
	var line: DialogueLine = dialogue_line
	var iterations: int = 0
	# La línea actual ya pide decisión: solo completar su texto
	while line != null and line.responses.size() == 0 and iterations < fast_forward_max_lines:
		line = await dialogue_resource.get_next_dialogue_line(line.next_id, temporary_game_states)
		iterations += 1
	_is_fast_forwarding = false
	if line == null:
		dialogue_line = null
	elif line == dialogue_line:
		dialogue_label.skip_typing()
	else:
		dialogue_line = line
		# Si se agotó el tope, el texto sale completo y el jugador sigue con next_action
		if line.responses.size() == 0:
			dialogue_label.skip_typing()


#region Signals


func _on_mutation_cooldown_timeout() -> void:
	if will_hide_balloon:
		will_hide_balloon = false
		balloon.hide()


func _on_mutated(_mutation: Dictionary) -> void:
	if not _mutation.is_inline:
		is_waiting_for_input = false
		will_hide_balloon = true
		mutation_cooldown.start(0.1)


func _on_balloon_gui_input(event: InputEvent) -> void:
	if Engine.get_process_frames() < _input_unlock_frame or _is_fast_forwarding: return
	if event is InputEventKey and event.is_echo(): return

	# Avance rápido (no se salta nunca el menú de respuestas)
	if event.is_action_pressed(fast_forward_action) and not responses_menu.visible:
		get_viewport().set_input_as_handled()
		fast_forward()
		return

	# Si el texto se está escribiendo, completarlo de golpe
	if dialogue_label.is_typing:
		var mouse_was_clicked: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed()
		var skip_button_was_pressed: bool = event.is_action_pressed(skip_action) or event.is_action_pressed(next_action)
		if mouse_was_clicked or skip_button_was_pressed:
			get_viewport().set_input_as_handled()
			AudioManager.play_ui(&"sfx_dialogue_skip")
			dialogue_label.skip_typing()
			return

	if not is_waiting_for_input: return
	if dialogue_line.responses.size() > 0: return

	# When there are no response options the balloon itself is the clickable thing
	get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		AudioManager.play_ui(&"sfx_dialogue_next")
		next(dialogue_line.next_id)
	elif event.is_action_pressed(next_action) and get_viewport().gui_get_focus_owner() == balloon:
		AudioManager.play_ui(&"sfx_dialogue_next")
		next(dialogue_line.next_id)


func _on_dialogue_label_spoke(letter: String, _letter_index: int, _speed: float) -> void:
	if _type_sound_cooldown > 0.0 or letter.strip_edges().is_empty():
		return
	_type_sound_cooldown = TYPE_SOUND_INTERVAL
	AudioManager.play_ui(&"sfx_dialogue_type")


func _on_responses_menu_response_focused(_response: Control) -> void:
	AudioManager.play_ui(&"sfx_dialogue_response_focus")


func _on_responses_menu_response_selected(response: DialogueResponse) -> void:
	AudioManager.play_ui(&"sfx_dialogue_response_select")
	next(response.next_id)


#endregion
