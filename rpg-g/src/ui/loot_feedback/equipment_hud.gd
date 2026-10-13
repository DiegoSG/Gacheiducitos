extends VBoxContainer
class_name EquipmentHud

## HUD de equipo (placeholder visual hasta el diseño definitivo del HUD): dos casillas bajo el
## icono del inventario con el arma activa y el escudo equipado. Solo lee Inventory.

const CELL_SIZE: Vector2 = Vector2(48, 48)
const EMPTY_ALPHA: float = 0.35

var _weapon_icon: TextureRect
var _weapon_placeholder: Label
var _weapon_slot_label: Label
var _shield_icon: TextureRect
var _shield_placeholder: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var weapon_cell: Array = _build_cell("⚔")
	_weapon_icon = weapon_cell[0]
	_weapon_placeholder = weapon_cell[1]
	_weapon_slot_label = weapon_cell[2]
	var shield_cell: Array = _build_cell("🛡")
	_shield_icon = shield_cell[0]
	_shield_placeholder = shield_cell[1]
	Inventory.equipment_changed.connect(_on_equipment_changed)
	Inventory.active_weapon_changed.connect(_on_active_weapon_changed)
	refresh()

func _exit_tree() -> void:
	if Inventory.equipment_changed.is_connected(_on_equipment_changed):
		Inventory.equipment_changed.disconnect(_on_equipment_changed)
	if Inventory.active_weapon_changed.is_connected(_on_active_weapon_changed):
		Inventory.active_weapon_changed.disconnect(_on_active_weapon_changed)

func refresh() -> void:
	_show(_weapon_icon, _weapon_placeholder, Inventory.get_active_weapon())
	_weapon_slot_label.text = "1" if Inventory.active_weapon == Inventory.SLOT_WEAPON_1 else "2"
	_show(_shield_icon, _shield_placeholder, Inventory.get_equipped(Inventory.SLOT_SHIELD))

func _on_equipment_changed(_slot: String, _item_id: String) -> void:
	refresh()

func _on_active_weapon_changed(_slot: String) -> void:
	refresh()

func _show(icon: TextureRect, placeholder: Label, data: ItemData) -> void:
	icon.texture = data.icon if data else null
	placeholder.visible = data == null or data.icon == null
	placeholder.modulate.a = EMPTY_ALPHA if data == null else 1.0

## Devuelve [icono, texto de casilla vacía, etiqueta de esquina].
func _build_cell(empty_glyph: String) -> Array:
	var cell: PanelContainer = PanelContainer.new()
	cell.custom_minimum_size = CELL_SIZE
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon: TextureRect = TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cell.add_child(icon)
	var placeholder: Label = Label.new()
	placeholder.text = empty_glyph
	placeholder.add_theme_font_size_override("font_size", 20)
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cell.add_child(placeholder)
	var corner: Label = Label.new()
	corner.add_theme_font_size_override("font_size", 12)
	corner.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	corner.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	cell.add_child(corner)
	add_child(cell)
	return [icon, placeholder, corner]
