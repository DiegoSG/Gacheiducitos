extends Node2D

# ID del ítem requerido para completar la misión
export(String) var required_item_id: String = ""

var quest_active: bool = false

signal quest_started
signal quest_completed

func interact() -> void:
    # llamada manual cuando el jugador presiona aceptar cerca del NPC
    if not quest_active:
        quest_active = true
        emit_signal("quest_started")
    else:
        if InventoryManager and InventoryManager.has_item(required_item_id):
            InventoryManager.remove_item(required_item_id)
            quest_active = false
            emit_signal("quest_completed")

# para el sistema de interacción del jugador (actionable_finder)
func action() -> void:
    interact()
