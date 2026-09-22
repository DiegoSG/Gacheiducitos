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
@onready var health_bar_container: HBoxContainer = get_node_or_null("TopLeftContainer/VBoxContainer/HealthBarContainer")
@onready var gold_label: Label = get_node_or_null("TopLeftContainer/VBoxContainer/GoldContainer/GoldLabel")

const COLOR_HEALTH_ACTIVE = Color(0.2, 0.9, 0.3, 1.0) # Verde activo
const COLOR_HEALTH_EMPTY = Color(0.25, 0.25, 0.25, 0.4) # Gris apagado

var _active_toasts: Dictionary = {} # item_id: String -> LootToastItem

func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	var stats := PlayerStats
	if stats:
		if not stats.health_changed.is_connected(_on_health_changed):
			stats.health_changed.connect(_on_health_changed)
		if not stats.gold_changed.is_connected(_on_gold_changed):
			stats.gold_changed.connect(_on_gold_changed)
		_update_health(stats.health, stats.max_health)
		_update_gold(stats.gold)

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _on_health_changed(current: int, max_val: int) -> void:
	_update_health(current, max_val)

func _on_gold_changed(amount: int) -> void:
	_update_gold(amount)

func _update_health(current: int, max_val: int) -> void:
	if not health_bar_container:
		return
		
	var existing_pips = health_bar_container.get_children()
	# Si la cantidad de barritas difiere del max_health, sincronizar cantidad
	while existing_pips.size() < max_val:
		var pip = ColorRect.new()
		pip.custom_minimum_size = Vector2(10, 24)
		health_bar_container.add_child(pip)
		existing_pips.append(pip)
		
	while existing_pips.size() > max_val:
		var last_pip = existing_pips.pop_back()
		last_pip.queue_free()
		
	# Actualizar colores activos/apagados
	for i in range(existing_pips.size()):
		var pip: ColorRect = existing_pips[i] as ColorRect
		if not pip:
			continue
		if i < current:
			pip.color = COLOR_HEALTH_ACTIVE
		else:
			pip.color = COLOR_HEALTH_EMPTY

func _update_gold(amount: int) -> void:
	if gold_label:
		gold_label.text = str(amount)


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
	var item_db := ItemDatabase
	var gold_item: ItemData = null
	if item_db:
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
