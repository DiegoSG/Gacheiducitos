---
name: godot-minigame-framework
description: Arquitectura y estándares para diseñar, desacoplar e implementar minijuegos (Excavación, Laberinto, Ritmo) y conectarlos con el inventario y estado global en RPG-G.
---

# Skill: Framework de Minijuegos (RPG-G)

Esta habilidad se activa al diseñar o implementar un minijuego en el proyecto (ej. Minijuego A: Excavación/Supaplex, Minijuego B: Laberinto, Minijuego C: Ritmo).

---

## 1. Principios de Diseño
- **Aislamiento Total:** El minijuego debe poder ejecutarse de forma 100% independiente desde su escena raíz o escena de pruebas (`test_*.tscn`).
- **Control de Ciclo de Vida (`MinigameBase`):**
  - Heredar siempre de `MinigameBase`.
  - Recolección de recompensas en búfer local: `add_reward(item_id: String, amount: int = 1)`.
  - `finish(success: bool, skip_screen: bool = false)`: Congela automáticamente todo el escenario (`get_tree().paused = true`), despliega la pantalla modal de Victoria/Derrota desacoplada (`process_mode = PROCESS_MODE_ALWAYS`) y espera confirmación del jugador (`ui_accept` o botón).
  - Al confirmar, despausa el árbol y emite `game_finished.emit(success, results)` hacia `GameManager.complete_minigame()`.
- **Entrada Desacoplada:** El minijuego procesa sus propios inputs específicos sin colisionar con los inputs de exploración del Overworld.

---

## 2. Puente con el Estado Global y Pipeline
- **Lanzamiento:** Mediante `GameTrigger` + `MinigameAction` (o prefab `minigame_interactable.tscn` en el Overworld).
- **Parámetros Inyectados:** `MinigameAction.config` inyecta parámetros de juego en `GameManager.minigame_config`.
- **Recompensas y Loot:** Al ganar, `GameManager.complete_minigame()` transfiere automáticamente las recompensas acumuladas en `session_rewards` hacia el singleton `Inventory` (`Inventory.add_item()`).
- **Retorno al Overworld:** `GameManager` reutiliza `ScreenFader` y los puntos de llegada (`ArrivalSpawnPoint` / `LevelPortal`) usando `win_level_path` / `win_spawn_id` si ganó, o `lose_level_path` / `lose_spawn_id` si perdió.

---

## 3. Checklist de Implementación
Antes de finalizar un minijuego:
1. Asegurar que la escena raíz hereda de `MinigameBase`.
2. Validar que al terminar llame únicamente a `finish(true)` o `finish(false)`.
3. No incluir timers ciegos que fuercen transiciones abruptas ni código duplicado de victoria/derrota (lo gestiona la clase base).
4. Probar en `test_[minijuego].tscn` y verificar el congelamiento completo y el retorno.

## 4. Notas de implementación (post-refactor)
- `GameManager.load_minigame(ruta)` (un argumento) pasa por `change_level` (fundido). GameManager es el ÚNICO que conecta `game_finished` a `complete_minigame`, también al ejecutar un minijuego suelto con F6. MinigameBase no se conecta sola.
- Recompensas: `add_reward(id, n)`; para oro usar `Inventory.GOLD_ITEM_ID`. Al ganar, GameManager las entrega con `Inventory.add_item` (el oro va a PlayerStats).
- Helpers en MinigameBase: `pick_item_from_pool(pool)`, `MinigameBase.get_item_icon(id)`, `MinigameBase.get_coin_texture()`. No duplicar esa lógica.
- Los menús de depuración `config_mg_*` viven en `src/minigames/tests/`; el camino oficial para lanzar minijuegos es `MinigameAction`.
- Trampolín: en modo ESPECIAL (`win_condition` 1) `target_value` es la altura de la plataforma especial.
