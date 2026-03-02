extends Node

signal inventory_changed

# Mapa de ID -> cantidad
var items: Dictionary = {}

# escena que será instanciada cuando se bote un objeto
@export var item_pickup_scene: PackedScene = preload("res://scenes/overworld/ItemPickup.tscn")

func _ready() -> void:
    # asegurarnos de iniciar vacío
    items.clear()

func add_item(item_id: String, count: int = 1) -> void:
    if items.has(item_id):
        items[item_id] += count
    else:
        items[item_id] = count
    emit_signal("inventory_changed")

func remove_item(item_id: String, count: int = 1) -> void:
    if not items.has(item_id):
        return
    items[item_id] -= count
    if items[item_id] <= 0:
        items.erase(item_id)
    emit_signal("inventory_changed")

func has_item(item_id: String) -> bool:
    return items.has(item_id) and items[item_id] > 0

func get_items() -> Dictionary:
    return items.duplicate() # evitar modificar original

# bota un ítem al suelo en la posición especificada
func drop_item(item_id: String, position: Vector2, count: int = 1) -> void:
    if not has_item(item_id):
        return
    remove_item(item_id, count)
	if item_pickup_scene:
		var pickup = item_pickup_scene.instantiate()
		if pickup:
			pickup.item_id = item_id
			if "quantity" in pickup:
				pickup.quantity = count
			pickup.global_position = position
			# añadir a la escena actual
			var root = get_tree().current_scene
			if root:
				root.add_child(pickup)
