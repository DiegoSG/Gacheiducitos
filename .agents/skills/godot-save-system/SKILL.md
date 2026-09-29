---
name: godot-save-system
description: Reglas del sistema de checkpoints, snapshots, respawn, autoguardado y slots de guardado en disco (CheckpointManager, SaveSystem, LevelExceptionConfig) de RPG-G. Usar al tocar persistencia, muerte/respawn o guardado/carga.
---

# Skill: Checkpoints y Guardado (RPG-G)

Especificación completa: `design/Sistema_Checkpoints_y_Guardado.md`. Leerla antes de cambios no triviales.

## 1. Piezas
- **`CheckpointManager` (autoload):** `register_level_entry(scene_path, scene_node, is_organic)` captura el snapshot de entrada de nivel; `respawn_player()` revierte y reaparece. Señal `player_respawned`.
- **`SaveSystem` (autoload):** slots en disco. `AUTOSAVE_SLOT_ID = 0` (`user://save_auto.json`), manuales `1..MAX_MANUAL_SLOTS` (`user://save_slot_%d.json`). API: `save_slot`, `load_slot`, `delete_slot`, `get_slot_metadata`, `get_all_slots_metadata`. Señales `game_saved`, `game_loaded`, `game_deleted`.
- **`LevelExceptionConfig` (componente de nivel):** `disable_autosave`, `respawn_level_path`, `respawn_spawn_id`.
- **Subsistemas serializables:** `PlayerStats`, `Inventory`, `NarrativeManager`, `WorldStateManager`. Cada uno expone `create_snapshot() -> Dictionary` y `restore_snapshot(snapshot: Dictionary) -> void`.

## 2. Invariantes (no romper)
1. **Minijuegos nunca** registran checkpoint ni disparan autosave (`MinigameBase` se filtra).
2. Autoguardado solo en transición **orgánica** a una escena **distinta** (`is_organic and not is_same_scene`) y sin `disable_autosave`. Cargar partida o arrancar el juego **no** es orgánico.
3. Orden de restauración al cargar: `WorldStateManager` → `NarrativeManager` → `Inventory` → `PlayerStats` → `GameManager.change_level(...)`.
4. Cada subsistema serializa **solo** su propio estado (desacoplamiento); `SaveSystem` solo orquesta.
5. Añadir un campo nuevo persistente = actualizar `create_snapshot` + `restore_snapshot` del subsistema dueño y tolerar su ausencia en saves antiguos (`dict.get("campo", default)`).
6. Interactables persistentes usan `persistence_id` único (ver `PersistenceIdHelper`).

## 3. Verificación
- Runners: `test_death_and_respawn_runner.gd`, `test_level_exception.tscn` (ver skill `godot-headless-test`).
- Casos mínimos al cambiar algo: minijuego no pisa checkpoint; save/load restaura HP, oro, energía, ítems, flags y posición; autosave no dispara al cargar.
