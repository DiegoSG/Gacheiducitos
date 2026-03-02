extends CanvasLayer

onready var label: Label = $Label

func _ready() -> void:
    if InventoryManager:
        InventoryManager.connect("inventory_changed", self, "_update")
    _update()

func _update() -> void:
    if InventoryManager:
        label.text = "Items: %s" % str(InventoryManager.items)
    else:
        label.text = "Inventory (no singleton)"
