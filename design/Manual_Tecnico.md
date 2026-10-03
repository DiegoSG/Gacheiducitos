# Manual Técnico del Sistema RPG-G

Este documento explica cómo funcionan técnicamente los sistemas implementados en el juego.

## 1. Estructura del Proyecto
*   `res://scenes/overworld/`: Escenas del mundo abierto (Player, Chest, Overworld).
*   `res://scenes/minigames/`: Escenas de minijuegos (Battle, Puzzle).
*   `res://scripts/managers/`: Singletons globales (GameManager).
*   `res://assets/`: Sprites, Tilesets y Sonidos.

## 2. Sistema de Movimiento (Player)
*   **Script:** `player.gd`
*   **Lógica:** Usa `Input.get_vector()` para obtener movimiento en 8 direcciones.
*   **Física:** Usa `move_and_slide()` de CharacterBody2D.
*   **Grupo:** El nodo Player se añade al grupo "player" para ser encontrado globalmente.

## 3. Sistema de Interacción
*   **Concepto:** El jugador tiene un área (`ActionableFinder`) que rota hacia donde mira.
*   **Detección:** Al pulsar "Espacio", busca áreas que solapan con `ActionableFinder`.
*   **Objetos Interactivos:** Deben tener un script con la función `action()`.
*   **Colisiones:**
    *   `InteractionArea`: Grande, para detectar el "Espacio".
    *   `PhysicsCollision`: Pequeña (base), para chocar físicamente.

## 4. Arquitectura de Managers y Transiciones
*   **Singletons Globales (Autoloads):**
    *   `GameManager.gd`: Transiciones de escena con `ScreenFader`, persistencia de retornos de minijuegos (`previous_scene_path`), y bus de eventos global.
    *   `AlertSystem.gd`: Registro y limpieza de enemigos perseguidores (`_active_pursuers`), y cálculo del estado global de alerta (`PEACE` vs `ALERT`).
    *   `CheckpointManager.gd`: Registro de puntos de control de nivel, captura de snapshots de inventario/estadísticas y gestión de la secuencia de `respawn_player()`.
    *   `WorldStateManager.gd`: Persistencia de variables y estados de interactuables del mapa.
    *   `PlayerStats.gd`: Control de salud (`health`, `max_health`) y oro.
    *   `Inventory.gd`: Almacenamiento de ítems y emisión de señales de inventario.
*   **Acceso a Singletons:** Acceso directo tipado por inferencia en GDScript (ej. `var gm := GameManager`), sin redeclarar `class_name` para evitar colisiones de tipo en Godot 4.x.

## 5. Overworld y TileMap
*   **Estructura:**
    *   `GroundLayer`: Suelo (sin colisión).
    *   `PropsLayer`: Objetos y muros (con colisión). Tiene `y_sort_enabled = true` para que el jugador se dibuje correctamente delante/detrás de los objetos.
*   **TileSet:** `core_tileset.tres` define las colisiones de los tiles.

## 6. Reglas de Desarrollo
*   **Inputs:** Usar siempre `Input.get_vector` para movimiento.
*   **Escalado:** Pixel Art requiere `Texture Filter: Nearest` en la configuración del proyecto.
