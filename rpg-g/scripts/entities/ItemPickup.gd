extends Area2D

# Identificador simple del ítem que se recogerá
e<br>export(String) var item_id: String = ""

func _ready() -> void:
    connect("body_entered", self, "_on_body_entered")

func _on_body_entered(body):
    if body.is_in_group("player"):
        if Inventory: # singleton asumido en autoload
            Inventory.add_item(item_id)
        queue_free()
