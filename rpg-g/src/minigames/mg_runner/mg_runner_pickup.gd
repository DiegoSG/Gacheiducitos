extends Area2D
class_name MG_RunnerPickup

signal collected(pickup: MG_RunnerPickup)

enum PickupType { COIN, RANDOM_ITEM, TARGET_OBJECT, AMMO }
@export var pickup_type: PickupType = PickupType.COIN
@export var item_id: String = "gold_coins"
@export var amount: int = 1
@export var is_victory_target: bool = false
var speed: float = 380.0

# Tamaños objetivo en píxeles (configurables en inspector)
@export var coin_target_size: float = 38.0
@export var item_target_size: float = 48.0
@export var target_object_size: float = 68.0
@export var ammo_target_size: float = 42.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var glow: Node2D = get_node_or_null("Glow")
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _pulse_time: float = 0.0
var _base_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	add_to_group("runner_pickup")
	area_entered.connect(_on_area_entered)
	_setup_visuals()

func _setup_visuals() -> void:
	if is_victory_target:
		pickup_type = PickupType.TARGET_OBJECT
		if glow:
			glow.visible = true
		_load_and_scale_item(item_id, target_object_size)
	elif pickup_type == PickupType.COIN:
		if glow:
			glow.visible = false
		var coin_tex = load("res://assets/items/icons/coin_v2.png")
		if not coin_tex:
			coin_tex = load("res://assets/items/icons/gold_coins.png")
		_apply_texture_and_scale(coin_tex, coin_target_size)
	elif pickup_type == PickupType.AMMO:
		if glow:
			glow.visible = false
		var ammo_tex = load("res://assets/items/icons/iron_key.png") # o icon.svg coloreado
		if not ammo_tex:
			ammo_tex = load("res://icon.svg")
		sprite.modulate = Color(1.0, 0.4, 0.2) # Resplandor anaranjado de proyectil/munición
		_apply_texture_and_scale(ammo_tex, ammo_target_size)
	else:
		if glow:
			glow.visible = false
		_load_and_scale_item(item_id, item_target_size)

func _load_and_scale_item(target_id: String, desired_pixel_size: float) -> void:
	# 1. Intentar cargar desde ItemData .tres
	var item_res_path = "res://data/items/%s.tres" % target_id
	if ResourceLoader.exists(item_res_path):
		var res = load(item_res_path)
		if res and "icon" in res and res.icon:
			_apply_texture_and_scale(res.icon, desired_pixel_size)
			return
			
	# 2. Intentar cargar desde icono png
	var png_path = "res://assets/items/icons/%s.png" % target_id
	if ResourceLoader.exists(png_path):
		var tex = load(png_path)
		if tex:
			_apply_texture_and_scale(tex, desired_pixel_size)
			return

	# 3. Fallback a icon.svg
	var fallback_tex = load("res://icon.svg")
	sprite.modulate = Color(1.0, 0.85, 0.1) if is_victory_target else Color(0.3, 0.7, 1.0)
	_apply_texture_and_scale(fallback_tex, desired_pixel_size)

func _apply_texture_and_scale(tex: Texture2D, target_size: float) -> void:
	if not tex:
		return
	sprite.texture = tex
	var s = tex.get_size()
	var max_dim = maxf(s.x, s.y)
	if max_dim > 0.0:
		var factor = target_size / max_dim
		_base_scale = Vector2(factor, factor)
		sprite.scale = _base_scale
	
	# Ajustar collider circular para que coincida con el tamaño visual
	if collision_shape:
		var circle = CircleShape2D.new()
		circle.radius = target_size * 0.5
		collision_shape.shape = circle

func _process(delta: float) -> void:
	position.x -= speed * delta
	
	if is_victory_target:
		_pulse_time += delta * 4.5
		var pulse = 1.0 + sin(_pulse_time) * 0.15
		sprite.scale = _base_scale * pulse
		if glow:
			glow.scale = Vector2(pulse * 1.3, pulse * 1.3)
			
	if position.x < -200.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("runner_player") and not area.get("is_dead"):
		collected.emit(self)
		queue_free()
