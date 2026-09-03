class_name MinigameBase
extends Node2D

## Clase base para todos los minijuegos. Estandariza la recolección de recompensas
## y la comunicación con el GameManager para la transición de regreso.

## Señal emitida al terminar el minijuego.
## success: true si se cumplió la condición de victoria, false si perdió o abortó.
## results: Diccionario con datos de la sesión, incluyendo ítems recolectados.
signal game_finished(success: bool, results: Dictionary)

## Diccionario interno para acumular recompensas durante la sesión antes de ganar.
## Formato: {"item_id": amount}
var session_rewards: Dictionary = {}

func _ready() -> void:
	# Intentar auto-conectar con el GameManager si no se ha conectado externamente
	var gm = get_tree().root.get_node_or_null("GameManager")
	if gm and gm.has_method("complete_minigame"):
		if not game_finished.is_connected(gm.complete_minigame):
			game_finished.connect(gm.complete_minigame)

## Añade un ítem al buffer local de la sesión.
## No se añade al inventario real hasta que se llama a finish().
func add_reward(item_id: String, amount: int = 1) -> void:
	if session_rewards.has(item_id):
		session_rewards[item_id] += amount
	else:
		session_rewards[item_id] = amount
	print("[MinigameBase] Recompensa añadida al buffer: ", item_id, " x", amount)

## Llamar a esta función cuando el minijuego termina (ganar o perder).
func finish(success: bool) -> void:
	print("[MinigameBase] Minijuego finalizado. Victoria: ", success)
	game_finished.emit(success, {"items": session_rewards})
