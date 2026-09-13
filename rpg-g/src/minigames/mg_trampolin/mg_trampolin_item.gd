extends Area2D
class_name MG_TrampolinItem

signal collected(item_id: String)

@export var item_id: String = ""

func _ready() -> void:
	add_to_group("trampolin_item")
	body_entered.connect(_on_body_entered)

func setup(p_item_id: String, texture: Texture2D) -> void:
	item_id = p_item_id
	if texture and has_node("Sprite2D"):
		var sprite = $Sprite2D
		sprite.texture = texture
		sprite.scale = Vector2(0.6, 0.6)

func _on_body_entered(body: Node2D) -> void:
	if body is MG_TrampolinPlayer or body.name == "TrampolinPlayer":
		collected.emit(item_id)
		queue_free()
