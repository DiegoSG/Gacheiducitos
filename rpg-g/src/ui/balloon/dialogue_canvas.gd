extends CanvasLayer

signal action_selected(action: String) # "accept", "reject", "close"

@onready var panel = $Control/Panel
@onready var npc_name_label = $Control/Panel/NPCName
@onready var dialogue_label = $Control/Panel/DialogueText
@onready var indicator = $Control/Panel/Indicator
@onready var buttons_container = $Control/Panel/Buttons
@onready var accept_btn = $Control/Panel/Buttons/AcceptBtn
@onready var reject_btn = $Control/Panel/Buttons/RejectBtn
@onready var close_btn = $Control/Panel/Buttons/CloseBtn

func _ready():
	panel.hide()
	indicator.hide()
	buttons_container.hide()
	
	# Connect buttons
	accept_btn.pressed.connect(_on_accept_pressed)
	reject_btn.pressed.connect(_on_reject_pressed)
	close_btn.pressed.connect(_on_close_pressed)

func show_thinking(npc_name: String):
	if not panel: _ready()
	npc_name_label.text = npc_name
	dialogue_label.text = "Pensando..."
	buttons_container.hide()
	panel.show()
	indicator.show()

func show_dialogue(npc_name: String, text: String, show_quest_options: bool = true):
	var options: Array[DialogueOption] = []
	if show_quest_options:
		var opt_accept = DialogueOption.new()
		opt_accept.text = "Aceptar"
		var opt_reject = DialogueOption.new()
		opt_reject.text = "Rechazar"
		options = [opt_accept, opt_reject]
		
	show_dialogue_nodal(npc_name, text, options)

func show_dialogue_nodal(npc_name: String, text: String, options: Array[DialogueOption]):
	if not panel: _ready()
	npc_name_label.text = npc_name
	dialogue_label.text = text
	indicator.hide()
	panel.show()
	
	_setup_buttons(options)

func _setup_buttons(options: Array[DialogueOption]):
	buttons_container.show()

	
	# Hide all initially
	accept_btn.hide()
	reject_btn.hide()
	close_btn.hide()
	
	if options.is_empty():
		close_btn.show()
		close_btn.text = "Cerrar"
	else:
		# Map options to our available buttons
		if options.size() >= 1:
			accept_btn.show()
			accept_btn.text = options[0].text
		if options.size() >= 2:
			reject_btn.show()
			reject_btn.text = options[1].text
		# Extend if needed

func hide_dialogue():
	panel.hide()
	buttons_container.hide()

func _on_accept_pressed():
	action_selected.emit("accept")
	if DialogueSystem.current_node:
		DialogueSystem.select_option(0)
	else:
		hide_dialogue()

func _on_reject_pressed():
	action_selected.emit("reject")
	if DialogueSystem.current_node:
		DialogueSystem.select_option(1)
	else:
		hide_dialogue()

func _on_close_pressed():
	action_selected.emit("close")
	if DialogueSystem.current_node:
		DialogueSystem.finish_dialogue()
	hide_dialogue()


func _input(event):
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		if panel.visible and not indicator.visible and not buttons_container.visible:
			hide_dialogue()
