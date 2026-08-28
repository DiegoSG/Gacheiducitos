---
name: godot-minigame-framework
description: Arquitectura y estándares para diseñar, desacoplar e implementar minijuegos (Excavación, Laberinto, Ritmo) y conectarlos con el inventario y estado global en RPG-G.
---

# Skill: Framework de Minijuegos (RPG-G)

Esta habilidad se activa al diseñar o implementar un minijuego en el proyecto (ej. Minijuego A: Excavación/Supaplex, Minijuego B: Laberinto, Minijuego C: Ritmo).

---

## 1. Principios de Diseño
- **Aislamiento Total:** El minijuego debe poder ejecutarse de forma 100% independiente desde su escena raíz o escena de pruebas (`test_*.tscn`).
- **Control de Ciclo de Vida:**
  - `start_game()`: Inicializa tablero, variables locales y temporizadores.
  - `pause_game()` / `resume_game()`: Manejo de menús de pausa o diálogos.
  - `finish_game(success: bool, results: Dictionary)`: Notifica el resultado a través de señales antes de cualquier transición.
- **Entrada Desacoplada:** El minijuego procesa sus propios inputs específicos sin colisionar con los inputs de exploración del Overworld.

---

## 2. Puente con el Estado Global
- **Recompensas y Loot:** Al ganar o recolectar ítems, el minijuego recopila un diccionario/array de resultados y utiliza el canal oficial de inventario:
  ```gdscript
  for item_id in collected_items:
      Inventory.add_item(item_id, 1)
  ```
- **Retorno al Overworld:** La salida del minijuego se gestiona a través de `GameManager` o la acción `MinigameAction` / `LevelAction`.

---

## 3. Checklist de Implementación
Antes de finalizar un minijuego:
1. Validar mecánicas de riesgo/recompensa.
2. Contar con feedback visual/auditivo de victoria o derrota.
3. Asegurar limpieza de nodos e instancias al salir (evitar fugas de memoria).
4. Probar en `test_[minijuego].tscn` de forma aislada.
