extends Node

class_name Inventory

signal inventory_changed

# Lista de IDs de ítems recogidos
var items: Array = []

func add_item(item_id: String) -> void:
    items.append(item_id)
    emit_signal("inventory_changed")

func remove_item(item_id: String) -> void:
    if item_id in items:
        items.erase(item_id)
        emit_signal("inventory_changed")

func has_item(item_id: String) -> bool:
    return item_id in items
