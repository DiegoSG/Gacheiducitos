extends Area2D

# Identificador simple del ítem que se recogerá
@export var item_id: String = ""
# cantidad en caso de pilas
@export var quantity: int = 1

func _ready() -> void:
	connect("body_entered", self, "_on_body_entered")

func _on_body_entered(body):
	if body.is_in_group("player"):
		if InventoryManager: # singleton asumido en autoload
			InventoryManager.add_item(item_id, quantity)
		queue_free()
