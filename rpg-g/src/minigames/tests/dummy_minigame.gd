class_name DummyMinigame
extends MinigameBase

@onready var win_btn: Button = $UI/VBoxContainer/WinButton
@onready var lose_btn: Button = $UI/VBoxContainer/LoseButton

func _ready() -> void:
	super._ready()
	if win_btn:
		win_btn.pressed.connect(_on_win_pressed)
	if lose_btn:
		lose_btn.pressed.connect(_on_lose_pressed)

func _on_win_pressed() -> void:
	add_reward("blue_potion", 1)
	add_reward("gold_coin", 5)
	finish(true)

func _on_lose_pressed() -> void:
	finish(false)
