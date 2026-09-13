extends CanvasLayer
class_name LootFeedbackManager

static var instance: LootFeedbackManager = null

const FLY_ICON_SCENE = preload("res://src/ui/loot_feedback/loot_fly_icon.tscn")

@onready var fx_container: Control = $FXContainer
@onready var inventory_anchor: Control = $InventoryAnchor
@onready var quickbar_container: HBoxContainer = $QuickbarContainer

func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS

func _exit_tree() -> void:
	if instance == self:
		instance = null

## Genera un icono volador desde una posición global del mundo o pantalla hacia el HUD del inventario
static func trigger_loot_pickup(item_data: ItemData, from_world_pos: Vector2, amount: int = 1) -> void:
	if not instance or not instance.is_inside_tree() or not item_data:
		return
	
	# Convertir posición de mundo a posición de pantalla
	var canvas_transform = instance.get_viewport().get_canvas_transform()
	var screen_pos: Vector2 = canvas_transform * from_world_pos
	
	instance._spawn_icon(item_data, screen_pos, amount)

## Genera un icono volador directamente desde una posición en pantalla (ideal para minijuegos o UI)
static func trigger_screen_loot(item_data: ItemData, from_screen_pos: Vector2, amount: int = 1) -> void:
	if not instance or not instance.is_inside_tree() or not item_data:
		return
	instance._spawn_icon(item_data, from_screen_pos, amount)

func _spawn_icon(item_data: ItemData, start_screen_pos: Vector2, amount: int) -> void:
	var fly_icon = FLY_ICON_SCENE.instantiate() as LootFlyIcon
	fx_container.add_child(fly_icon)
	fly_icon.setup(item_data.icon, amount)
	
	var target_screen_pos: Vector2 = inventory_anchor.global_position + (inventory_anchor.size * 0.5)
	
	fly_icon.animate_to(start_screen_pos, target_screen_pos, func():
		_punch_inventory_anchor()
	)

func _punch_inventory_anchor() -> void:
	if not inventory_anchor:
		return
	var tween = create_tween()
	tween.tween_property(inventory_anchor, "scale", Vector2(1.25, 1.25), 0.08).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(inventory_anchor, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_BOUNCE)
