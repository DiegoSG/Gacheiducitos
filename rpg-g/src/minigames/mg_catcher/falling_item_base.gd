extends Area2D
class_name FallingItemBase

signal hit_floor
signal caught(item_type: int)
signal expired(is_critical: bool)

enum ItemType { POINT, BOMB }

@export var item_type: ItemType = ItemType.POINT
@export var fall_speed_multiplier: float = 1.0
@export var is_critical: bool = false
@export var item_id: String = ""

var base_speed: float = 200.0
var current_speed: float = 200.0
var is_active: bool = false
var is_on_floor: bool = false
var floor_timer: float = 0.0
## Seconds an item that does NOT kill stays on the floor before expiring.
## Set by the minigame via setup() (config "floor_wait_time"); lower = harder.
var floor_wait_time: float = 3.0
const FLOOR_BLINK_TIME: float = 1.0

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func setup(p_base_speed: float, p_pos: Vector2, p_is_critical: bool = false, p_item_id: String = "", p_texture: Texture2D = null, p_floor_wait_time: float = 3.0) -> void:
	base_speed = p_base_speed
	current_speed = base_speed * fall_speed_multiplier
	global_position = p_pos
	is_critical = p_is_critical
	item_id = p_item_id
	is_active = true
	is_on_floor = false
	floor_wait_time = maxf(p_floor_wait_time, 0.0)
	if p_texture and has_node("Sprite2D"):
		$Sprite2D.texture = p_texture

func _process(delta: float) -> void:
	if not is_active:
		return
	
	if not is_on_floor:
		global_position.y += current_speed * delta
		# Fallback cleanup if it drifts too far off-screen
		if global_position.y > get_viewport_rect().size.y + 200:
			queue_free()
	else:
		floor_timer += delta
		# Blink during the last second (or the whole time if the wait is shorter)
		if floor_timer >= floor_wait_time - FLOOR_BLINK_TIME:
			var blink_rate = 15.0
			modulate.a = 0.3 if fmod(floor_timer * blink_rate, 2.0) > 1.0 else 1.0
			
		if floor_timer >= floor_wait_time:
			_expire_on_floor()

func _expire_on_floor() -> void:
	is_active = false
	expired.emit(is_critical)
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	if is_on_floor or not is_active:
		return
	if area.is_in_group("catcher_floor"):
		AudioManager.play_sfx(&"sfx_catch_floor_hit")
		# What kills (bombs) disappears on touching the floor, without waiting
		if item_type == ItemType.BOMB:
			hit_floor.emit(item_type)
			is_active = false
			queue_free()
		else:
			# Point/collectible item rests on the floor for floor_wait_time
			if floor_wait_time <= 0.0:
				hit_floor.emit(item_type)
				_expire_on_floor()
				return
			is_on_floor = true
			global_position.y = area.global_position.y - 40.0
			hit_floor.emit(item_type)

func _on_body_entered(body: Node2D) -> void:
	if not is_active:
		return
	if body.is_in_group("catcher_player") or body.name == "CatcherPlayer":
		is_active = false
		caught.emit(item_type)
		queue_free()
