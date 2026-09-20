extends CanvasLayer
class_name LootFeedbackManager

## Gestor global de feedback visual de recompensas e inventario.
## Muestra notificaciones tipo Toast ([Icono] x N [Nombre]) directamente
## al lado del icono de inventario (mochila) al recolectar ítems o monedas.

static var instance: LootFeedbackManager = null

const TOAST_SCENE = preload("res://src/ui/loot_feedback/loot_toast_item.tscn")

@onready var inventory_anchor: Control = $InventoryAnchor
@onready var quickbar_container: HBoxContainer = $QuickbarContainer
@onready var toast_container: VBoxContainer = get_node_or_null("ToastContainer")

var _active_toasts: Dictionary = {} # item_id: String -> LootToastItem

func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS

func _exit_tree() -> void:
	if instance == self:
		instance = null

## Notifica la recolección de un ítem en el mundo (cofre, suelo, enemigo)
## y despliega inmediatamente el toast al lado del inventario con feedback visual
static func trigger_loot_pickup(item_data: ItemData, _from_world_pos: Vector2 = Vector2.ZERO, amount: int = 1) -> void:
	if not instance or not instance.is_inside_tree() or not item_data:
		return
	instance.show_toast(item_data, amount)
	instance._punch_inventory_anchor()

## Notifica la recolección de botín desde pantalla (minijuegos o UI de recompensas)
static func trigger_screen_loot(item_data: ItemData, _from_screen_pos: Vector2 = Vector2.ZERO, amount: int = 1) -> void:
	if not instance or not instance.is_inside_tree() or not item_data:
		return
	instance.show_toast(item_data, amount)
	instance._punch_inventory_anchor()

## Despliega directamente el toast de loot para un ítem específico
static func trigger_toast(item_data: ItemData, amount: int = 1) -> void:
	if not instance or not instance.is_inside_tree() or not item_data:
		return
	instance.show_toast(item_data, amount)
	instance._punch_inventory_anchor()

## Notifica la recolección de monedas de oro (creando el toast de gold_coins automáticamente)
static func trigger_gold(amount: int) -> void:
	if not instance or not instance.is_inside_tree() or amount <= 0:
		return
	var item_db = instance.get_node_or_null("/root/ItemDatabase")
	var gold_item: ItemData = null
	if item_db and item_db.has_method("get_item"):
		gold_item = item_db.get_item("gold_coins")
	if not gold_item:
		gold_item = load("res://data/items/gold_coins.tres")
	if gold_item:
		instance.show_toast(gold_item, amount)
		instance._punch_inventory_anchor()

## Despliega o apila una notificación de toast al lado del icono de inventario
func show_toast(item_data: ItemData, amount: int = 1) -> void:
	if not item_data or amount <= 0:
		return
		
	if not toast_container:
		toast_container = get_node_or_null("ToastContainer")
		if not toast_container:
			return
			
	var item_id: String = item_data.id
	
	# Si ya existe un toast activo para este ítem y sigue en pantalla, acumular cantidad
	if _active_toasts.has(item_id) and is_instance_valid(_active_toasts[item_id]) and _active_toasts[item_id].is_inside_tree():
		var existing_toast: LootToastItem = _active_toasts[item_id]
		existing_toast.add_amount(amount)
		return
		
	# Si no existe, instanciar nuevo toast
	var toast = TOAST_SCENE.instantiate() as LootToastItem
	toast_container.add_child(toast)
	_active_toasts[item_id] = toast
	
	toast.tree_exited.connect(func():
		if _active_toasts.get(item_id) == toast:
			_active_toasts.erase(item_id)
	)
	
	toast.setup(item_data, amount)

func _punch_inventory_anchor() -> void:
	if not inventory_anchor:
		return
	var tween = create_tween()
	tween.tween_property(inventory_anchor, "scale", Vector2(1.2, 1.2), 0.08).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(inventory_anchor, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_BOUNCE)
