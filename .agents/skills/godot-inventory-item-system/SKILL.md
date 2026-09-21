---
name: godot-inventory-item-system
description: Estandarización para crear ítems, gestionar inventario, estadísticas de jugador y verificación de consistencia en RPG-G.
---

# Skill: Sistema de Ítems e Inventario (RPG-G)

Esta habilidad se activa al registrar nuevos ítems, diseñar tablas de loot, ajustar estadísticas de jugador o interactuar con el inventario global.

---

## 1. Arquitectura de Ítems e Inventario
- **`ItemDatabase` (Autoload):** Diccionario central con la definición, metadatos y texturas/iconos de todos los ítems.
- **`Inventory` (Autoload):** Administra los stacks, cantidades, añadir/remover objetos y emitir señales de cambio (`inventory_updated`).
- **`PlayerStats` (Autoload):** Maneja atributos (salud, energía, monedas) y sincronización con ítems consumibles o equipables.

---

## 2. Convenciones de Identificadores (Item ID)
- Identificadores en `snake_case` y únicos (ej. `wooden_sword`, `healing_herb`, `ancient_coin`).
- Las descripciones y nombres visibles deben estar centralizados en los recursos de datos (`res://data/...`).

---

## 3. Scripts de Utilidad y Verificación
- Usar `res://src/core/utils/verify_items.gd` para verificar que no existan IDs duplicados o recursos de iconos rotos.
- Usar `res://src/core/tools/generate_items.gd` para generación por lotes de recursos de ítems si aplica.

---

## 4. Variables Narrativas y Sincronización con Diálogos
- **`NarrativeDefaults` (`res://src/core/data/narrative_defaults.gd`):** Archivo auto-generado por el backend de `DialogueApp` al guardar variables en la app web. Define la constante `DEFAULTS: Dictionary` con los valores iniciales.
- **`NarrativeManager` (Autoload):** En `_ready()` carga dinámicamente `NarrativeDefaults` y precarga las banderas por defecto (`flags`). Los diálogos acceden y modifican estas banderas con `NarrativeManager.get_flag("nombre")` y `NarrativeManager.set_flag("nombre", valor)`.

## 5. Ítems Consumibles y Pipeline de Acciones (`ItemAction`)
- **`ItemAction` (`res://src/core/pipeline/actions/item_action.gd`):** Recurso que hereda de `ActionResource`. Permite añadir o quitar ítems (`operation: "add" | "remove"`) especificando `item_id` y `amount`. Dispara feedback visual automático a través de `LootFeedbackManager.trigger_toast()`.
- **Consumo de Ítems (`Inventory.use_item`):** `ItemData` expone `heal_amount` y `damage_amount`. Al consumir un ítem desde `InventoryUI` (doble clic) o mediante código (`Inventory.use_item(item_id)`), se aplican los efectos sobre `PlayerStats` (`heal()` / `take_damage()`), y se descuenta 1 unidad del inventario emitiendo `inventory_changed` y `PlayerStats.health_changed`.

## 6. Persistencia y Generación de IDs Únicos (`PersistenceIdHelper`)
- **`PersistenceIdHelper` (`res://src/core/utils/persistence_id_helper.gd`):** Utilidad `@tool` con `generate_id(node, prefix) -> String` que genera identificadores deterministas y únicos para objetos persistentes en escena (`DialogueEvent`, `PressurePlate`).
