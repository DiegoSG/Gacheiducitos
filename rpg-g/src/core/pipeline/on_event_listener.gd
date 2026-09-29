class_name OnEventListener
extends Node

## Escucha GameManager.game_event y dispara el GameTrigger padre o indicado.

@export var listen_for_event: String = ""
@export var target_trigger: NodePath = NodePath("")

func _ready() -> void:
	if not GameManager.game_event.is_connected(_on_game_event):
		GameManager.game_event.connect(_on_game_event)

func _exit_tree() -> void:
	if GameManager.game_event.is_connected(_on_game_event):
		GameManager.game_event.disconnect(_on_game_event)

func _on_game_event(event_name: String, _data: Variant) -> void:
	if listen_for_event.is_empty() or event_name != listen_for_event:
		return
	var target: Node = get_node_or_null(target_trigger) if not target_trigger.is_empty() else get_parent()
	if target is GameTrigger:
		(target as GameTrigger).force_trigger()
	else:
		push_warning("OnEventListener '%s': target_trigger no válido." % name)
