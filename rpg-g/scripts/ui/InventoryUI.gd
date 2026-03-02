extends CanvasLayer

onready var label: Label = $Label

func _ready() -> void:
    if InventoryManager:
        InventoryManager.connect("inventory_changed", self, "_update")
    _update()

func _update() -> void:
    if InventoryManager:
        var parts: Array = []
        for key in InventoryManager.items.keys():
            var cnt = InventoryManager.items[key]
            parts.append("%s x%d" % [key, cnt])
        label.text = "Inventory: %s" % ", ".join(parts)
    else:
        label.text = "Inventory (no singleton)"
