class_name OnEventListener
extends Node

## Escucha GameManager.game_event y dispara el GameTrigger padre o indicado.

@export var listen_for_event: String = ""
@export var target_trigger: NodePath = NodePath("")

func _ready() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.has_signal("game_event"):
		if not gm.game_event.is_connected(_on_game_event):
			gm.game_event.connect(_on_game_event)
	else:
		push_warning("OnEventListener '%s': GameManager no encontrado." % name)

func _exit_tree() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.has_signal("game_event") and gm.game_event.is_connected(_on_game_event):
		gm.game_event.disconnect(_on_game_event)

func _on_game_event(event_name: String, _data: Variant) -> void:
	if listen_for_event.is_empty() or event_name != listen_for_event:
		return
	var t: Node = get_node_or_null(target_trigger) if not target_trigger.is_empty() else get_parent()
	if t and t.has_method("force_trigger"):
		t.force_trigger()
	else:
		push_warning("OnEventListener '%s': target_trigger no válido." % name)
