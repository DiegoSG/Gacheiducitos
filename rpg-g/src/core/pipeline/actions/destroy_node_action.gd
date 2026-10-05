class_name DestroyNodeAction
extends ActionResource

## Elimina (queue_free) u oculta y deshabilita un nodo del escenario (ej. rocas destructibles, barreras temporales).

enum DestroyMode {
	QUEUE_FREE,      ## Elimina el nodo de la memoria de forma segura
	HIDE_AND_DISABLE ## Lo oculta y desactiva sus colisiones sin destruirlo
}

## Ruta al nodo objetivo
@export var target_node_path: NodePath

## Modo de destrucción
@export var mode: DestroyMode = DestroyMode.QUEUE_FREE

## Duración de un desvanecimiento (fade out) antes de destruir/ocultar (0 = instantáneo)
@export var fade_duration: float = 0.0

func get_action_name() -> String:
	return "DestroyNodeAction (%s)" % str(target_node_path)

func execute(trigger_node: Node) -> void:
	if target_node_path.is_empty():
		push_warning("DestroyNodeAction: target_node_path está vacío.")
		finished.emit()
		return
		
	var target: Node = trigger_node.get_node_or_null(target_node_path)
	if not is_instance_valid(target):
		push_warning("DestroyNodeAction: Nodo no encontrado en %s" % str(target_node_path))
		finished.emit()
		return
		
	if fade_duration > 0.0 and target is CanvasItem:
		var canvas_item: CanvasItem = target as CanvasItem
		var tween: Tween = trigger_node.create_tween()
		tween.tween_property(canvas_item, "modulate:a", 0.0, fade_duration)
		if wait_to_finish:
			await tween.finished
			_finalize_destroy(target)
			finished.emit()
			return
		else:
			tween.finished.connect(func() -> void: _finalize_destroy(target))
			finished.emit()
			return
	else:
		_finalize_destroy(target)
		finished.emit()

func _finalize_destroy(target: Node) -> void:
	if not is_instance_valid(target):
		return
	AudioManager.play_sfx(&"sfx_destroy_node")
		
	if mode == DestroyMode.QUEUE_FREE:
		target.queue_free()
	else:
		if target is CanvasItem:
			(target as CanvasItem).visible = false
		_disable_collision_recursively(target)

func _disable_collision_recursively(node: Node) -> void:
	if node is CollisionShape2D or node is CollisionPolygon2D:
		node.set_deferred("disabled", true)
	for child: Node in node.get_children():
		_disable_collision_recursively(child)
