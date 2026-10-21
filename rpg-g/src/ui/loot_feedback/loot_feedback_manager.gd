extends CanvasLayer
class_name LootFeedbackManager

## Global manager for visual reward and inventory feedback.
## Shows Toast-style notifications ([Icon] x N [Name]) right next to
## the inventory icon (backpack) when collecting items or coins.

static var instance: LootFeedbackManager = null

const TOAST_SCENE: PackedScene = preload("res://src/ui/loot_feedback/loot_toast_item.tscn")

@onready var inventory_anchor: Control = $InventoryAnchor
@onready var quickbar_container: HBoxContainer = $QuickbarContainer
@onready var toast_container: VBoxContainer = get_node_or_null("ToastContainer")
@onready var health_bar_container: HBoxContainer = get_node_or_null("TopLeftContainer/VBoxContainer/HealthBarContainer")
@onready var status_container: HBoxContainer = get_node_or_null("TopLeftContainer/VBoxContainer/StatusContainer")
@onready var gold_label: Label = get_node_or_null("TopLeftContainer/VBoxContainer/GoldContainer/GoldLabel")

const COLOR_HEALTH_ACTIVE: Color = Color(0.2, 0.9, 0.3, 1.0) # Verde activo
const COLOR_HEALTH_EMPTY: Color = Color(0.25, 0.25, 0.25, 0.4) # Gris apagado

var _slot_icons: Array[TextureRect] = []
var _slot_counts: Array[Label] = []
var _active_toasts: Dictionary = {} # item_id: String -> LootToastItem
## Last item shown per slot: the sound only plays when the assignment changes, not the amount.
var _slot_item_ids: Array[String] = []
var _quick_slots_synced: bool = false

func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if not PlayerStats.health_changed.is_connected(_on_health_changed):
		PlayerStats.health_changed.connect(_on_health_changed)
	if not PlayerStats.gold_changed.is_connected(_on_gold_changed):
		PlayerStats.gold_changed.connect(_on_gold_changed)
	if not PlayerStats.status_applied.is_connected(_on_status_changed):
		PlayerStats.status_applied.connect(_on_status_changed)
	if not PlayerStats.status_removed.is_connected(_on_status_changed):
		PlayerStats.status_removed.connect(_on_status_changed)
	if not PlayerStats.stats_changed.is_connected(_refresh_status_ui):
		PlayerStats.stats_changed.connect(_refresh_status_ui)
	_update_health(PlayerStats.health, PlayerStats.get_max_health())
	_rebuild_status_row()
	_update_gold(PlayerStats.gold)
	_build_quickbar()

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _on_health_changed(current: int, max_val: int) -> void:
	_update_health(current, max_val)

func _on_status_changed(_arg: Variant) -> void:
	AudioManager.play_ui(&"sfx_hud_status_row_changed")
	_refresh_status_ui()

func _refresh_status_ui() -> void:
	_update_health(PlayerStats.health, PlayerStats.get_max_health())
	_rebuild_status_row()

## Row with the name of each active status, tinted with its color.
func _rebuild_status_row() -> void:
	if not status_container:
		return
	for child: Node in status_container.get_children():
		status_container.remove_child(child)
		child.queue_free()
	for effect: StatusEffectData in PlayerStats.get_active_statuses():
		var label: Label = Label.new()
		label.text = effect.display_name if not effect.display_name.is_empty() else effect.id
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", effect.hud_color)
		status_container.add_child(label)

func _on_gold_changed(amount: int) -> void:
	_update_gold(amount)

func _update_health(current: int, max_val: int) -> void:
	if not health_bar_container:
		return
		
	var existing_pips: Array[Node] = health_bar_container.get_children()
	# If the number of pips differs from max_health, sync the count
	while existing_pips.size() < max_val:
		var pip: ColorRect = ColorRect.new()
		pip.custom_minimum_size = Vector2(10, 24)
		health_bar_container.add_child(pip)
		existing_pips.append(pip)
		
	while existing_pips.size() > max_val:
		var last_pip: Node = existing_pips.pop_back()
		last_pip.queue_free()
		
	# If there is an active status, active pips are tinted with the last applied status' color
	var active_color: Color = COLOR_HEALTH_ACTIVE
	var last_status: StatusEffectData = PlayerStats.get_last_status()
	if last_status != null:
		active_color = last_status.hud_color

	# Update active/inactive colors
	for i in range(existing_pips.size()):
		var pip: ColorRect = existing_pips[i] as ColorRect
		if not pip:
			continue
		if i < current:
			pip.color = active_color
		else:
			pip.color = COLOR_HEALTH_EMPTY

func _update_gold(amount: int) -> void:
	if gold_label:
		gold_label.text = str(amount)


## Single public API: shows the loot toast for an item (gold included) next to the inventory
## and animates the backpack icon.
static func trigger_toast(item_data: ItemData, amount: int = 1) -> void:
	if not instance or not instance.is_inside_tree() or not item_data:
		return
	instance.show_toast(item_data, amount)
	instance._punch_inventory_anchor()

## Shows or stacks a toast notification next to the inventory icon
func show_toast(item_data: ItemData, amount: int = 1) -> void:
	if not item_data or amount <= 0:
		return
		
	if not toast_container:
		toast_container = get_node_or_null("ToastContainer")
		if not toast_container:
			return
			
	var item_id: String = item_data.id
	
	# If an active toast for this item already exists and is still on screen, accumulate the amount
	if _active_toasts.has(item_id) and is_instance_valid(_active_toasts[item_id]) and _active_toasts[item_id].is_inside_tree():
		var existing_toast: LootToastItem = _active_toasts[item_id]
		existing_toast.add_amount(amount)
		return
		
	# If not, instantiate a new toast
	var toast: LootToastItem = TOAST_SCENE.instantiate() as LootToastItem
	toast_container.add_child(toast)
	_active_toasts[item_id] = toast
	AudioManager.play_ui(&"sfx_loot_toast_new")
	
	toast.tree_exited.connect(func() -> void:
		if _active_toasts.get(item_id) == toast:
			_active_toasts.erase(item_id)
	)
	
	toast.setup(item_data, amount)

func _punch_inventory_anchor() -> void:
	if not inventory_anchor:
		return
	AudioManager.play_ui(&"sfx_loot_inventory_bounce")
	var tween: Tween = create_tween()
	tween.tween_property(inventory_anchor, "scale", Vector2(1.2, 1.2), 0.08).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(inventory_anchor, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_BOUNCE)

## Minimal HUD of 4 quick-slot cells (visual placeholder).
func _build_quickbar() -> void:
	if not quickbar_container:
		return
	for i: int in QuickSlots.SLOT_COUNT:
		var cell: PanelContainer = PanelContainer.new()
		cell.custom_minimum_size = Vector2(48, 48)
		var icon: TextureRect = TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cell.add_child(icon)
		var key_label: Label = Label.new()
		key_label.text = str(i + 1)
		key_label.add_theme_font_size_override("font_size", 12)
		cell.add_child(key_label)
		var count_label: Label = Label.new()
		count_label.add_theme_font_size_override("font_size", 12)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		cell.add_child(count_label)
		quickbar_container.add_child(cell)
		_slot_icons.append(icon)
		_slot_counts.append(count_label)
	_connect_quick_slots.call_deferred()

func _connect_quick_slots() -> void:
	var slots: QuickSlots = QuickSlots.instance
	if slots == null:
		return
	if not slots.slot_changed.is_connected(_on_quick_slot_changed):
		slots.slot_changed.connect(_on_quick_slot_changed)
	for i: int in QuickSlots.SLOT_COUNT:
		_on_quick_slot_changed(i, slots.get_slot(i))
	_quick_slots_synced = true

func _on_quick_slot_changed(index: int, item_id: String) -> void:
	if index < 0 or index >= _slot_icons.size():
		return
	while _slot_item_ids.size() < _slot_icons.size():
		_slot_item_ids.append("")
	if _quick_slots_synced and not QuickSlots.is_restoring and _slot_item_ids[index] != item_id:
		AudioManager.play_ui(&"sfx_hud_slot_changed")
	_slot_item_ids[index] = item_id
	var data: ItemData = ItemDatabase.get_item(item_id) if not item_id.is_empty() else null
	var count: int = Inventory.get_owned_count(item_id) if data else 0
	_slot_icons[index].texture = data.icon if data else null
	_slot_icons[index].modulate.a = 1.0 if count > 0 else 0.35
	_slot_counts[index].text = ("x%d" % count) if data and data.stackable else ""
