class_name MinigameBase
extends Node2D

## Base class for all minigames. Standardizes reward collection
## and communication with the GameManager for the return transition.

## Signal emitted when the minigame ends.
## success: true if the win condition was met, false if lost or aborted.
## results: Dictionary with session data, including collected items.
signal game_finished(success: bool, results: Dictionary)

## Internal dictionary to accumulate rewards during the session before winning.
## Format: {"item_id": amount}
var session_rewards: Dictionary = {}
var _is_finishing: bool = false
var _result_ui: CanvasLayer = null
var _pause_menu: PauseMenu = null

const PAUSE_MENU_SCENE: PackedScene = preload("res://src/ui/menus/pause_menu.tscn")

## Coin texture paths (with fallback) and a cache shared between minigames.
const COIN_TEXTURE_PATH: String = "res://assets/items/icons/coin_v2.png"
const COIN_TEXTURE_FALLBACK_PATH: String = "res://assets/items/icons/gold_coins.png"
static var _coin_texture_cache: Texture2D = null

# _notification runs across the whole script hierarchy; _ready does not, because minigames override it without super().
func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		AudioManager.play_sfx(&"sfx_mg_start")

## Adds an item to the session's local buffer.
## It is not added to the real inventory until finish() is called.
func add_reward(item_id: String, amount: int = 1) -> void:
	if session_rewards.has(item_id):
		session_rewards[item_id] += amount
	else:
		session_rewards[item_id] = amount
	AudioManager.play_sfx(&"sfx_mg_reward_added")

## Call this function when the minigame ends (win or lose).
func finish(success: bool, skip_screen: bool = false) -> void:
	if _is_finishing:
		return
	_is_finishing = true
	
	# If we are in headless mode (automated tests) or skipping is requested, finish immediately
	if skip_screen or DisplayServer.get_name() == "headless":
		_emit_finished(success)
		return
		
	# Pause right after: uses the UI bus so it is not cut off
	AudioManager.play_ui(&"sfx_mg_win" if success else &"sfx_mg_lose")

	# Fully freeze the game (physics, projectiles, timers, entities)
	get_tree().paused = true
	
	_show_result_screen(success)

func _show_result_screen(success: bool) -> void:
	AudioManager.play_music(&"music_mg_result")
	AudioManager.play_ui(&"sfx_mg_result_shown")
	_result_ui = CanvasLayer.new()
	_result_ui.layer = 120 # Above any minigame UI or HUD
	_result_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_result_ui)
	
	# Root full-screen container control that processes during pause
	var root_ctrl: Control = Control.new()
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.process_mode = Node.PROCESS_MODE_ALWAYS
	_result_ui.add_child(root_ctrl)
	
	# Semi-transparent dark backdrop
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.8)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.add_child(backdrop)
	
	# Centered container
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.add_child(center)
	
	# Container panel
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
	
	# Win / Lose title
	var title_label: Label = Label.new()
	title_label.text = "¡VICTORIA!" if success else "¡DERROTA!"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.modulate = Color(0.25, 0.95, 0.35) if success else Color(0.95, 0.25, 0.25)
	vbox.add_child(title_label)
	
	# Descriptive message and reward breakdown
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
	
	# Interactive button to continue
	var continue_btn: Button = Button.new()
	continue_btn.text = "Continuar (Volver al mapa)"
	continue_btn.custom_minimum_size = Vector2(260, 48)
	continue_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	continue_btn.pressed.connect(func() -> void: _on_continue_pressed(success))
	vbox.add_child(continue_btn)
	continue_btn.grab_focus()
	
	# Keyboard shortcut hint
	var prompt_label: Label = Label.new()
	prompt_label.text = "O presiona ESPACIO / ENTER para volver"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 12)
	prompt_label.modulate = Color(0.75, 0.75, 0.75)
	vbox.add_child(prompt_label)

## `pause` during the minigame opens the pause menu (Resume / Options / Abandon).
## Does nothing if the game is already paused by another system or if the minigame has already ended.
func _unhandled_input(event: InputEvent) -> void:
	if _is_finishing or _pause_menu != null or get_tree().paused:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		AudioManager.play_ui(&"sfx_mg_pause")
		_pause_menu = PAUSE_MENU_SCENE.instantiate() as PauseMenu
		_pause_menu.mode = PauseMenu.Mode.MINIGAME
		_pause_menu.closed.connect(func() -> void: _pause_menu = null)
		_pause_menu.abandon_requested.connect(_on_abandon_requested)
		add_child(_pause_menu)

## Abandoning counts as losing: the session's items are discarded and the defeat path is used.
func _on_abandon_requested() -> void:
	session_rewards.clear()
	AudioManager.play_ui(&"sfx_mg_abandon")
	finish(false)

func _exit_tree() -> void:
	# Make sure the game is never left frozen when leaving the scene
	if get_tree() and get_tree().paused:
		get_tree().paused = false

func _on_continue_pressed(success: bool) -> void:
	AudioManager.play_ui(&"sfx_mg_result_continue")
	if get_tree() and get_tree().paused:
		get_tree().paused = false
	if _result_ui:
		_result_ui.queue_free()
		_result_ui = null
	_emit_finished(success)

func _emit_finished(success: bool) -> void:
	AudioManager.play_ui(&"sfx_mg_finished")
	game_finished.emit(success, {"items": session_rewards})

## Picks an item id from a pool. Accepts an Array of String (uniform choice)
## or an Array of Dictionary {"id": String, "chance": float} (cumulative probability).
## Returns "" if nothing is picked (empty pool or the roll falls in no entry).
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

## Returns the item's icon from ItemDatabase, or null if it does not exist or has no icon.
static func get_item_icon(item_id: String) -> Texture2D:
	if item_id.is_empty():
		return null
	var data: ItemData = ItemDatabase.get_item(item_id)
	if data == null:
		return null
	return data.icon

## Returns the coin texture (coin_v2.png with fallback to gold_coins.png), cached.
static func get_coin_texture() -> Texture2D:
	if _coin_texture_cache == null:
		_coin_texture_cache = load(COIN_TEXTURE_PATH) as Texture2D
		if _coin_texture_cache == null:
			_coin_texture_cache = load(COIN_TEXTURE_FALLBACK_PATH) as Texture2D
	return _coin_texture_cache
