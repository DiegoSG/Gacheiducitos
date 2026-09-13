extends Control

## Escena de prueba interactiva para validar el sistema de Feedback Visual de Loot y Toasts

@onready var btn_single_item: Button = $VBoxButtons/BtnSingleItem
@onready var btn_stack_item: Button = $VBoxButtons/BtnStackItem
@onready var btn_multi_items: Button = $VBoxButtons/BtnMultiItems
@onready var btn_gold: Button = $VBoxButtons/BtnGold

var green_herb: ItemData
var red_potion: ItemData
var blue_gem: ItemData
var gold_coins: ItemData

func _ready() -> void:
	green_herb = load("res://data/items/green_herb.tres")
	red_potion = load("res://data/items/red_potion.tres")
	blue_gem = load("res://data/items/blue_gem.tres")
	gold_coins = load("res://data/items/gold_coins.tres")
	
	if btn_single_item:
		btn_single_item.pressed.connect(_on_single_item_pressed)
	if btn_stack_item:
		btn_stack_item.pressed.connect(_on_stack_item_pressed)
	if btn_multi_items:
		btn_multi_items.pressed.connect(_on_multi_items_pressed)
	if btn_gold:
		btn_gold.pressed.connect(_on_gold_pressed)

func _on_single_item_pressed() -> void:
	LootFeedbackManager.trigger_toast(green_herb, 1)

func _on_stack_item_pressed() -> void:
	LootFeedbackManager.trigger_toast(green_herb, 1)

func _on_multi_items_pressed() -> void:
	LootFeedbackManager.trigger_toast(red_potion, 2)
	LootFeedbackManager.trigger_toast(blue_gem, 1)
	LootFeedbackManager.trigger_gold(25)

func _on_gold_pressed() -> void:
	LootFeedbackManager.trigger_gold(10)
