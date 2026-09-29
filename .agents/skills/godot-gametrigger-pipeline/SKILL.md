---
name: godot-gametrigger-pipeline
description: Guía y estándares para crear y extender eventos cinemáticos e interactivos usando el sistema GameTrigger y ActionResource en RPG-G.
---

# Skill: Pipeline de Eventos (GameTrigger)

Esta habilidad se activa al crear, modificar o extender la lógica de eventos en el mapa, interacciones con NPCs, cinemáticas o secuencias narrativas usando la arquitectura `GameTrigger`.

---

## 1. Concepto Central
El sistema de eventos se basa en el nodo `GameTrigger` (`Area2D` con lógica extendida) y recursos `ActionResource` ejecutados en secuencia o paralelo.

---

## 2. Modos de Activación (`TriggerMode`)
- `ON_ENTER`: Disparado al entrar un actor en el área (colisión).
- `ON_EXIT`: Disparado al salir del área.
- `INTERACT`: Requiere que el jugador esté en el área y presione `ui_accept` / botón de interacción.
- `AUTO_START`: Se ejecuta inmediatamente al cargar la escena (controlado comúnmente por una bandera/flag).

---

## 3. Parámetros de GameTrigger
- `one_shot` (bool): Si es `true`, el trigger se deshabilita permanentemente tras ejecutarse una vez.
- `persistence_id` (String): Clave única opcional para persistir `_has_triggered` en `WorldStateManager` al cambiar de nivel.
- `conditions` (`ConditionSet`, `res://src/core/variables/`): lista de `Condition` (`var_path`, `operator`, `value`) combinadas con `mode` ALL/ANY. Sin ConditionSet la condición es verdadera.
- `VariableWatcher` (`res://src/core/variables/variable_watcher.gd`): nodo que vigila un `ConditionSet` y llama `force_trigger()` en un `GameTrigger` en la transición falso->verdadero.
- `actions_if_true` (Array[ActionResource]): Secuencia ejecutada si la condición se cumple (o por defecto).
- `actions_if_false` (Array[ActionResource]): Secuencia ejecutada si la condición no se cumple.


---

## 4. Control de Timing (`wait_to_finish`)
- **`wait_to_finish = false` (Paralelo):** Dispara la acción y pasa de inmediato a la siguiente sin bloquear la cola.
- **`wait_to_finish = true` (Secuencial):** Pausa la ejecución de la lista hasta que la acción complete su ciclo (`finished.emit()`).

---

## 5. Acciones Existentes (`ActionResource`)
Ubicadas en `res://src/core/pipeline/actions/`:
- `AnimAction`: Reproduce animaciones en `AnimationPlayer` o `AnimatedSprite2D`.
- `DialogueAction`: Inicia un diálogo vía `DialogueManager`.
- `DoorAction`: Bloquea, desbloquea, abre o cierra puertas/portales (`LevelPortal`).
- `DestroyNodeAction`: Elimina o desvanece obstáculos y nodos del mapa.
- `VariableAction`: SET/ADD/TOGGLE sobre variables `flag.*` de `GameVariables`.
- `GoldAction`: Añade o sustrae monedas de oro con cobro atómico y eventos de éxito/fallo (`on_success_event`, `on_fail_event`).
- `HealthAction`: Modifica la salud del jugador en `PlayerStats` (curación completa `full_heal`, curación `+X`, o daño `-X`).
- `ItemAction`: Añade o sustrae ítems del inventario mediante recurso `ItemData` con sustracción atómica y eventos de éxito/fallo.
- `LevelAction`: Cambia de nivel con `GameManager.change_level(level_scene_path, arrival_id)` (fundido + checkpoint). Debe ser la última acción.
- `MinigameAction`: Carga y transiciona a un minijuego.
- `QuestAction`: Actualiza el progreso de misiones.
- `RunTriggerAction`: Ejecuta otro `GameTrigger` de forma remota.
- `SpawnAction`: Instancia escenas o efectos en una posición dada.
- `ToggleTriggerAction`: Habilita o deshabilita otros triggers.
- `VisColAction`: Modifica visibilidad (`is_visible`) y colisiones (`collisions_enabled`) recursivamente.
- `WaitAction`: Introduce una pausa temporal (en segundos).

---

## 6. Creación de Nuevas Acciones
Al crear una nueva acción personalizada:
1. Heredar de `ActionResource` (`class_name MiNuevaAction extends ActionResource`).
2. Implementar `func execute(trigger_context: Node) -> void:`.
3. Si soporta `wait_to_finish`, emitir la señal `finished` cuando la operación asíncrona termine.

---

## 7. Puente de Eventos y Diálogos (`DialogueEvent` y `OnEventListener`)
- **`GameManager.trigger_event(event_name: String, event_data: Variant)`**: Permite disparar eventos globales desde cualquier lugar, especialmente desde diálogos generados en `DialogueApp` vía `do GameManager.trigger_event("NombreDelActor")`.
- **`DialogueEvent` (`res://src/overworld/interactables/dialogue_event.gd`)**: Nodo `Node2D` invisible en runtime (con icono y etiqueta visual en el editor).
  - Escucha la señal `GameManager.game_event`.
  - Se activa si el evento coincide con su `name` o con `event_id`.
  - Ejecuta una lista secuencial/paralela de `actions: Array[ActionResource]`.
  - Soporta `one_shot` y persistencia de estado mediante `persistence_id` en `WorldStateManager`.
- **`OnEventListener` (`res://src/core/pipeline/on_event_listener.gd`)**: Componente que escucha `GameManager.game_event` y llama a `force_trigger()` en un `GameTrigger` tradicional del nivel.

---

## 8. Persistencia de Interactables
Los interactables del mapa (`PressurePlate`, `Chest`, `SwitchInteractable`, `DialogueEvent`) implementan el patrón canónico con `WorldStateManager`:
- `@export_group("Persistencia")`
- `@export var persistence_id: String = ""`
- `_restore_state()` en `_ready()` cargando desde `WorldStateManager.load_state(persistence_id)`.
- `_persist_state()` al cambiar de estado guardando en `WorldStateManager.save_state(persistence_id, data)`.

## 9. Ejecución y semántica (post-refactor)
- Toda lista de acciones se ejecuta con `ActionRunner.run(actions, context)` (`res://src/core/pipeline/action_runner.gd`), que respeta `wait_to_finish`. GameTrigger, DialogueEvent, PressurePlate y SwitchInteractable lo usan; no escribir bucles propios.
- Condición (`conditions: ConditionSet` con rutas de GameVariables): se evalúa en todos los modos. Verdadera o sin condición -> `actions_if_true`; falsa -> `actions_if_false`.
- `ON_ENTER_AND_EXIT`: al entrar `actions_if_true`, al salir `actions_if_false` (nunca repite las de entrada). Si la condición es falsa al entrar no se ejecuta nada. `one_shot` = un ciclo completo.
- Helpers en `ActionResource`: `ActionResource.parse_value(texto)` (true/false/verdadero/falso/int/float) y `emit_game_event(nombre)`.
- Autoloads se usan por nombre directo; no comprobar si existen.
