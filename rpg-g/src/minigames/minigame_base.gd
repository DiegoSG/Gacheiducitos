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

## Rutas de la textura de moneda (con fallback) y caché compartida entre minijuegos.
const COIN_TEXTURE_PATH: String = "res://assets/items/icons/coin_v2.png"
const COIN_TEXTURE_FALLBACK_PATH: String = "res://assets/items/icons/gold_coins.png"
static var _coin_texture_cache: Texture2D = null

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
	var root_ctrl: Control = Control.new()
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.process_mode = Node.PROCESS_MODE_ALWAYS
	_result_ui.add_child(root_ctrl)
	
	# Fondo oscuro semi-transparente
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.8)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.add_child(backdrop)
	
	# Contenedor centrado
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.add_child(center)
	
	# Panel contenedor
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 240)
	center.add_child(panel)
	
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)
	
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)
	
	# Título de Victoria / Derrota
	var title_label: Label = Label.new()
	title_label.text = "¡VICTORIA!" if success else "¡DERROTA!"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.modulate = Color(0.25, 0.95, 0.35) if success else Color(0.95, 0.25, 0.25)
	vbox.add_child(title_label)
	
	# Mensaje descriptivo y desglose de recompensas
	var desc_label: Label = Label.new()
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 16)
	
	if success:
		if session_rewards.is_empty():
			desc_label.text = "¡Has completado el desafío con éxito!"
		else:
			var loot_text: String = "¡Desafío superado!\n\nRecompensas obtenidas:"
			for item_id: String in session_rewards:
				loot_text += "\n• %s: +%d" % [item_id.capitalize().replace("_", " "), session_rewards[item_id]]
			desc_label.text = loot_text
	else:
		desc_label.text = "No has logrado superar el desafío esta vez.\n¡Inténtalo de nuevo!"
	vbox.add_child(desc_label)
	
	# Botón interactivo para continuar
	var continue_btn: Button = Button.new()
	continue_btn.text = "Continuar (Volver al mapa)"
	continue_btn.custom_minimum_size = Vector2(260, 48)
	continue_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	continue_btn.pressed.connect(func() -> void: _on_continue_pressed(success))
	vbox.add_child(continue_btn)
	continue_btn.grab_focus()
	
	# Indicador de atajo de teclado
	var prompt_label: Label = Label.new()
	prompt_label.text = "O presiona ESPACIO / ENTER para volver"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 12)
	prompt_label.modulate = Color(0.75, 0.75, 0.75)
	vbox.add_child(prompt_label)

func _exit_tree() -> void:
	# Asegurar que el juego nunca quede congelado al salir de la escena
	if get_tree() and get_tree().paused:
		get_tree().paused = false

func _on_continue_pressed(success: bool) -> void:
	if get_tree() and get_tree().paused:
		get_tree().paused = false
	if _result_ui:
		_result_ui.queue_free()
		_result_ui = null
	_emit_finished(success)

func _emit_finished(success: bool) -> void:
	game_finished.emit(success, {"items": session_rewards})

## Elige un id de ítem de un pool. Acepta Array de String (elección uniforme)
## o Array de Dictionary {"id": String, "chance": float} (probabilidad acumulada).
## Devuelve "" si no se elige nada (pool vacío o la tirada no cae en ninguna entrada).
func pick_item_from_pool(pool: Array) -> String:
	if pool.is_empty():
		return ""
	if pool[0] is Dictionary:
		var roll: float = randf()
		var accum: float = 0.0
		for entry: Variant in pool:
			if not entry is Dictionary:
				continue
			var entry_dict: Dictionary = entry
			accum += float(entry_dict.get("chance", 0.3))
			if roll <= accum:
				return str(entry_dict.get("id", ""))
		return ""
	return str(pool[randi() % pool.size()])

## Devuelve el icono del ítem según ItemDatabase, o null si no existe o no tiene icono.
static func get_item_icon(item_id: String) -> Texture2D:
	if item_id.is_empty():
		return null
	var data: ItemData = ItemDatabase.get_item(item_id)
	if data == null:
		return null
	return data.icon

## Devuelve la textura de la moneda (coin_v2.png con fallback a gold_coins.png), cacheada.
static func get_coin_texture() -> Texture2D:
	if _coin_texture_cache == null:
		_coin_texture_cache = load(COIN_TEXTURE_PATH) as Texture2D
		if _coin_texture_cache == null:
			_coin_texture_cache = load(COIN_TEXTURE_FALLBACK_PATH) as Texture2D
	return _coin_texture_cache
