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

## 4. GameManager y Transiciones
*   **Singleton:** `GameManager.gd` (Autoload).
*   **Función:** Gestiona el cambio entre Overworld y Minijuegos.
*   **Persistencia:**
    1.  Al entrar a un minijuego: Guarda `previous_scene_path` y `player_return_position`.
    2.  Al salir: Carga la escena guardada y reposiciona al jugador.

## 5. Overworld y TileMap
*   **Estructura:**
    *   `GroundLayer`: Suelo (sin colisión).
    *   `PropsLayer`: Objetos y muros (con colisión). Tiene `y_sort_enabled = true` para que el jugador se dibuje correctamente delante/detrás de los objetos.
*   **TileSet:** `core_tileset.tres` define las colisiones de los tiles.

## 6. Reglas de Desarrollo
*   **Inputs:** Usar siempre `Input.get_vector` para movimiento.
*   **Escalado:** Pixel Art requiere `Texture Filter: Nearest` en la configuración del proyecto.
