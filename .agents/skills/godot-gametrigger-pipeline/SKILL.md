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
- `require_condition` (bool): Habilita evaluación de banderas en `NarrativeManager`.
- `condition_flag` (String): Nombre de la bandera a consultar.
- `condition_expected_value` (Variant): Valor esperado (ej. `true`, `false`, número).
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
- `FlagAction`: Modifica banderas en `NarrativeManager`.
- `LevelAction`: Cambia de escena/nivel mediante `GameManager`.
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
