class_name MinigameBase
extends Node2D

## Clase base para todos los minijuegos. Estandariza la recolección de recompensas
## y la comunicación con el GameManager para la transición de regreso.

## Señal emitida al terminar el minijuego.
## success: true si se cumplió la condición de victoria, false si perdió o abortó.
## results: Diccionario con datos de la sesión, incluyendo ítems recolectados.
signal game_finished(success: bool, results: Dictionary)

## Diccionario interno para acumular recompensas durante la sesión antes de ganar.
## Formato: {"item_id": amount}
var session_rewards: Dictionary = {}
var _is_finishing: bool = false
var _result_ui: CanvasLayer = null
var _last_success: bool = false

func _enter_tree() -> void:
	_connect_game_manager()

func _ready() -> void:
	_connect_game_manager()

func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE or what == NOTIFICATION_READY:
		_connect_game_manager()

func _connect_game_manager() -> void:
	var gm := GameManager
	if not gm and get_tree() and get_tree().root:
		gm = GameManager
	if gm:
		if not game_finished.is_connected(gm.complete_minigame):
			game_finished.connect(gm.complete_minigame)

## Añade un ítem al buffer local de la sesión.
## No se añade al inventario real hasta que se llama a finish().
func add_reward(item_id: String, amount: int = 1) -> void:
	if session_rewards.has(item_id):
		session_rewards[item_id] += amount
	else:
		session_rewards[item_id] = amount
	print("[MinigameBase] Recompensa añadida al buffer: ", item_id, " x", amount)

## Llamar a esta función cuando el minijuego termina (ganar o perder).
func finish(success: bool, skip_screen: bool = false) -> void:
	if _is_finishing:
		return
	_is_finishing = true
	_last_success = success
	print("[MinigameBase] Minijuego finalizado. Victoria: ", success)
	
	# Si estamos en modo headless (tests automatizados) o se solicita omitir, finalizar de inmediato
	if skip_screen or DisplayServer.get_name() == "headless":
		_emit_finished(success)
		return
		
	# Congelar completamente el juego (físicas, proyectiles, timers, entidades)
	get_tree().paused = true
	
	_show_result_screen(success)

func _show_result_screen(success: bool) -> void:
	_result_ui = CanvasLayer.new()
	_result_ui.layer = 120 # Por encima de cualquier UI o HUD de minijuego
	_result_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_result_ui)
	
	# Control contenedor raíz de pantalla completa que procesa en pausa
	var root_ctrl = Control.new()
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.process_mode = Node.PROCESS_MODE_ALWAYS
	_result_ui.add_child(root_ctrl)
	
	# Fondo oscuro semi-transparente
	var backdrop = ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.8)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.add_child(backdrop)
	
	# Contenedor centrado
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.add_child(center)
	
	# Panel contenedor
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 240)
	center.add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)
	
	# Título de Victoria / Derrota
	var title_label = Label.new()
	title_label.text = "¡VICTORIA!" if success else "¡DERROTA!"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.modulate = Color(0.25, 0.95, 0.35) if success else Color(0.95, 0.25, 0.25)
	vbox.add_child(title_label)
	
	# Mensaje descriptivo y desglose de recompensas
	var desc_label = Label.new()
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 16)
	
	if success:
		if session_rewards.is_empty():
			desc_label.text = "¡Has completado el desafío con éxito!"
		else:
			var loot_text = "¡Desafío superado!\n\nRecompensas obtenidas:"
			for item_id in session_rewards:
				loot_text += "\n• %s: +%d" % [item_id.capitalize().replace("_", " "), session_rewards[item_id]]
			desc_label.text = loot_text
	else:
		desc_label.text = "No has logrado superar el desafío esta vez.\n¡Inténtalo de nuevo!"
	vbox.add_child(desc_label)
	
	# Botón interactivo para continuar
	var continue_btn = Button.new()
	continue_btn.text = "Continuar (Volver al mapa)"
	continue_btn.custom_minimum_size = Vector2(260, 48)
	continue_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	continue_btn.pressed.connect(func(): _on_continue_pressed(success))
	vbox.add_child(continue_btn)
	continue_btn.grab_focus()
	
	# Indicador de atajo de teclado
	var prompt_label = Label.new()
	prompt_label.text = "O presiona ESPACIO / ENTER para volver"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 12)
	prompt_label.modulate = Color(0.75, 0.75, 0.75)
	vbox.add_child(prompt_label)

func _exit_tree() -> void:
	# Asegurar que el juego nunca quede congelado al salir de la escena
	if get_tree() and get_tree().paused:
		get_tree().paused = false

func _unhandled_input(event: InputEvent) -> void:
	if _is_finishing and _result_ui != null:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select") or event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_on_continue_pressed(_last_success)

func _on_continue_pressed(success: bool) -> void:
	if get_tree() and get_tree().paused:
		get_tree().paused = false
	if _result_ui:
		_result_ui.queue_free()
		_result_ui = null
	_emit_finished(success)

func _emit_finished(success: bool) -> void:
	_connect_game_manager()
	game_finished.emit(success, {"items": session_rewards})
