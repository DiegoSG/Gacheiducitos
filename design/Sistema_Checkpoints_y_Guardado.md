# Especificación de Arquitectura: Sistema de Checkpoints y Guardado Persistente

**Fecha:** 22 de Septiembre, 2026  
**Proyecto:** RPG-G (Godot 4.6)  
**Estado:** Documentación / Propuesta Técnica (Sin código implementado)  

---

## 1. Visión General del Sistema

El objetivo de esta especificación es formalizar el rediseño del sistema de checkpoints dinámicos y la incorporación de un sistema de guardado (Save/Load) manual y automático en disco (`user://savegame.json`).

### Principios Fundamentales
1. **Exclusividad del Overworld:** Los minijuegos (`MinigameBase`) no generan checkpoints ni disparan guardados automáticos. Toda persistencia ocurre en el mapa principal (Overworld).
2. **Snapshot de Inicio de Nivel:** Cada vez que el jugador ingresa a un nivel del Overworld, se registra un snapshot de inicio de nivel para revertir pérdidas si el jugador muere.
3. **Persistencia Dual (Memoria vs. Disco):**
   - **Snapshots en memoria:** Utilizados por `CheckpointManager` para respawns rápidos durante la sesión de juego.
   - **Archivo en disco:** Serialización completa de la partida para permitir cerrar el juego, cargar partida o guardar manualmente.
4. **Desacoplamiento Estricto:** Cada subsistema (`PlayerStats`, `Inventory`, `NarrativeManager`, `WorldStateManager`) es responsable de su propio serializado (`create_snapshot()` y `restore_snapshot()`).

---

## 2. Alcance de Datos a Capturar

Tanto el snapshot de inicio de nivel como el guardado manual/automático deben capturar las siguientes dimensiones:

| Dominio | Datos a Serializar | Fuente de Datos / Autoload |
| :--- | :--- | :--- |
| **Jugador / Estadísticas** | `health`, `max_health`, `gold`, `energy`, `max_energy` | `PlayerStats` |
| **Posición y Nivel** | `scene_path` del nivel actual, `spawn_id`, `global_position` del jugador | `GameManager` / `Player` |
| **Inventario** | Diccionario de items con cantidades `{"item_id": amount}` | `Inventory` |
| **Narrativa / Diálogos** | Diccionario de flags globales `flags` y misiones activas/completadas `quests` | `NarrativeManager` |
| **Persistencia del Mundo** | Estados de interactuables (cofres abiertos, puertas, switches, drops recogidos) | `WorldStateManager` |
| **Metadata de Guardado** | Timestamp, tiempo de juego, contador de checkpoints, tipo de guardado (`manual` o `auto`) | `SaveSystem` / `CheckpointManager` |

---

## 3. Comportamiento y Flujos Técnicos

### 3.1 Inicio de Nivel en el Overworld (`register_level_entry`)
1. Al cambiar de escena mediante `GameManager.change_level()` o al iniciar el juego:
   - Se valida que la nueva escena **no** herede de `MinigameBase`.
   - Se captura el snapshot de inicio de nivel:
     - `PlayerStats` (HP, Oro, Energía).
     - `Inventory` (Items y cantidades).
     - `NarrativeManager` (Flags narrativas y estado de misiones).
     - `WorldStateManager` (Estado de interactuables del nivel).
     - Posición de aparición (`spawn_id` o coordenadas iniciales).
2. **Configuración de Excepción (`LevelExceptionConfig`):**
   - El nivel puede incluir un nodo componente `LevelExceptionConfig`.
   - Permite definir:
     - `disable_autosave`: omite el guardado automático al cruzar a este nivel (ideal para salas de Bosses).
     - `respawn_level_path`: nivel al que se redirige al jugador si muere aquí.
     - `respawn_spawn_id`: identificador de `ArrivalSpawnPoint` donde reaparece el jugador tras morir.
3. **Punto de Control Activo y Autoguardado:**
   - Si no hay excepción, se promueve el nivel actual como checkpoint activo con reaparición por posición de entrada.
   - Si hay excepción, se redirige el checkpoint activo a `respawn_level_path` y `respawn_spawn_id`.
   - **Regla de Autoguardado:** En cada transición orgánica entre niveles distintos (`is_organic and not is_same_scene`), se dispara un guardado automático a disco (`SaveSystem.save_slot(AUTOSAVE_SLOT_ID)`), salvo que el nivel contenga `LevelExceptionConfig` con `disable_autosave = true`.

### 3.2 Secuencia de Muerte y Respawn (`respawn_player`)
1. El jugador pierde toda su salud (`PlayerStats.health == 0`).
2. Se inicia la secuencia de muerte y bloqueo temporal de inputs.
3. `CheckpointManager` revierte:
   - `WorldStateManager` al snapshot de entrada del nivel donde murió (reseteando cofres/drops recogidos antes de llegar al checkpoint).
   - Restaura `PlayerStats` (HP, Oro, Energía) al snapshot del checkpoint activo.
   - Restaura `Inventory` al snapshot del checkpoint activo.
   - Restaura `NarrativeManager` a las flags vigentes en dicho checkpoint.
4. `GameManager.change_level()` transporta al jugador a la escena del checkpoint activo en el marcador `"RespawnPoint"` o posición guardada.

### 3.3 Guardado Manual por el Jugador (`save_game`)
1. Puede ser invocado desde la UI (menú de pausa), un interactuable de guardado (piedra de guardado/campamento), o atajo.
2. Captura en tiempo real exacto:
   - Nivel actual (`scene_file_path`).
   - Coordenadas exactas del jugador (`player.global_position`).
   - HP, Oro y Energía actuales (`PlayerStats`).
   - Inventario actual (`Inventory`).
   - Flags narrativas actuales (`NarrativeManager`).
   - Estado de todos los interactuables persistidos (`WorldStateManager`).
3. Serializa a archivo JSON en `user://savegame.json` (con backup de seguridad `user://savegame.bak`).

### 3.4 Carga de Partida (`load_game`)
1. Lee y valida el archivo `user://savegame.json`.
2. Restaura los subsistemas en orden:
   - `WorldStateManager.restore_snapshot(...)`
   - `NarrativeManager.restore_snapshot(...)`
   - `Inventory.restore_snapshot(...)`
   - `PlayerStats.restore_snapshot(...)`
3. `GameManager.change_level(saved_scene_path, "", saved_exact_pos, true)` posiciona al jugador en las coordenadas exactas donde guardó.

---

## 4. Estructura de Datos Propuesta para el Archivo de Guardado (`savegame.json`)

```json
{
  "version": 1,
  "save_type": "manual",
  "timestamp": 1726998000,
  "playtime_seconds": 1240.5,
  "level": {
    "scene_path": "res://src/overworld/levels/Lvl02.tscn",
    "player_position": { "x": 450.0, "y": 320.0 }
  },
  "player_stats": {
    "health": 4,
    "max_health": 4,
    "energy": 100,
    "max_energy": 100,
    "gold": 250
  },
  "inventory": {
    "red_potion": 3,
    "dungeon_key": 1
  },
  "narrative": {
    "flags": {
      "met_barnaby": true,
      "gate_unlocked": true
    },
    "quests": {
      "quest_main_01": "completed"
    }
  },
  "world_state": {
    "chest_lvl01_room02": { "is_open": true },
    "pickup_potion_42": { "collected": true }
  }
}
```

---

## 5. Matriz de Tareas Pendientes (Checklist de Implementación)

### Fase A: Preparación de Métodos Snapshot en Subsistemas
- [ ] **PlayerStats:**
  - [ ] Añadir variables de energía: `energy: int = 100`, `max_energy: int = 100`.
  - [ ] Señal `energy_changed(current: int, max_val: int)`.
  - [ ] Extender `create_snapshot()` y `restore_snapshot()` para incluir `energy` y `max_energy`.
- [ ] **NarrativeManager:**
  - [ ] Implementar `create_snapshot() -> Dictionary` (retorna copia de `flags` y `quests`).
  - [ ] Implementar `restore_snapshot(snapshot: Dictionary) -> void`.

### Fase B: Extensión de CheckpointManager
- [ ] **Snapshot de Inicio de Nivel Extendido:**
  - [ ] Incluir `NarrativeManager.create_snapshot()` en `level_entry_world_state_snapshot`.
  - [ ] Filtrar escenas de minijuegos para garantizar que `register_level_entry` solo procese Overworld.
- [ ] **Contador y Frecuencia de Autoguardado:**
  - [ ] Exportar / configurar `checkpoints_until_autosave: int = 3`.
  - [ ] Variable interna `_checkpoints_passed_count: int = 0`.
  - [ ] Disparar guardado automático al alcanzar el umbral.

### Fase C: Módulo de Guardado Persistente (`SaveSystem` / Guardado a Disco)
- [ ] **Serialización y Validación de Disco:**
  - [ ] Implementar `save_to_file(slot_path: String, save_type: String) -> bool`.
  - [ ] Implementar `load_from_file(slot_path: String) -> bool`.
  - [ ] Manejo de archivos de respaldo (`.bak`) ante cierres inesperados.
- [ ] **API de Guardado Manual:**
  - [ ] Función pública `save_current_state(is_autosave: bool = false) -> void`.
  - [ ] Función pública `load_saved_state() -> void`.

### Fase D: Pruebas y Validación
- [ ] Crear runner de pruebas `test_checkpoint_and_save_runner.gd`:
  - [ ] Validar que un minijuego no sobrescriba el snapshot de checkpoint ni dispare autosave.
  - [ ] Validar guardado manual y restauración fidedigna de HP, Oro, Energía, Items, Flags y Posición.
  - [ ] Validar autoguardado tras $N$ checkpoints en el Overworld.
