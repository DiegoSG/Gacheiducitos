extends CanvasLayer

onready var label: Label = $Label

func _ready() -> void:
    if Inventory:
        Inventory.connect("inventory_changed", self, "_update")
    _update()

func _update() -> void:
    if Inventory:
        label.text = "Items: %s" % str(Inventory.items)
    else:
        label.text = "Inventory (no singleton)"
