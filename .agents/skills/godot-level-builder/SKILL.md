---
name: godot-level-builder
description: Checklist técnico para crear o modificar niveles del Overworld en RPG-G (plantilla, WorldBoundaryManager, ArrivalSpawnPoint, LevelPortal, persistencia e interactables). Usar al crear/editar escenas en src/overworld/levels/.
---

# Skill: Construcción de Niveles Overworld (RPG-G)

Guías fuente: `design/Guia_Creacion_Niveles.md` y `design/Level_Design_Items_Guide.md`.

## 1. Base
- Hoy no existe plantilla en el repo (`template_level.tscn`/`prototype_template.tscn` fueron eliminadas): duplicar un `level_XX.tscn` existente y limpiarlo, o pedir al usuario que cree la plantilla. Archivo `snake_case` (`level_forest_entrance.tscn`), nodo raíz `PascalCase`.
- Grilla oficial **60x60 px**, tileset `core_tileset.tres`. Capas: `GroundLayer`, `DetailLayer`, `PropsLayer` (`y_sort_enabled`).
- `WorldBoundaryManager`: `width`/`height` en px cubriendo toda el área jugable.

## 2. Conexiones
- Al menos un `ArrivalSpawnPoint` con `arrival_id = "start"`; IDs únicos por nivel (`from_<origen>`, `from_<mg>_win/lose`).
- Cada `LevelPortal`: `target_level_path` existente + `arrival_id` que **exista en el nivel destino**. Verificar ambos lados (ida y vuelta).
- Puertas con llave: asignar `key` (recurso `ItemData`); asignarla marca `is_locked`. `consume_key` la quita al abrir.
- Minijuegos: `minigame_interactable.tscn` + `MinigameAction` con rutas/spawns de victoria y derrota válidos.

## 3. Persistencia y checkpoints
- Todo interactable con estado (`Chest`, `PressurePlate`, `SwitchInteractable`, `DialogueEvent`, pickups) con `persistence_id` único, generado con `PersistenceIdHelper`.
- Si el nivel es sala de jefe o necesita respawn especial: añadir `LevelExceptionConfig` (ver skill `godot-save-system`).

## 4. Eventos
- Lógica de eventos solo vía `GameTrigger` + `ActionResource` (skill `godot-gametrigger-pipeline`). No scripts ad-hoc por nivel.

## 5. Validación
- Grep de coherencia: que cada `arrival_id` referenciado por portales exista en su destino y que no haya `persistence_id` duplicados (agente `scene-auditor`).
- Arranque de humo headless de la escena (skill `godot-headless-test`); recorrido manual lo hace el usuario.
- La IA no diseña el layout ni el contenido narrativo del nivel: solo estructura técnica y placeholders.

## 6. Notas de implementación
- Persistencia: el `persistence_id` exportado solo se rellena a mano para estado permanente. Vacío = estado efímero del nivel. En código usar `PersistenceIdHelper.runtime_key(self, persistence_id)` y NUNCA escribir en la propiedad exportada (en scripts @tool quedaría guardado en la escena).
- Capas de colisión por código: usar `CollisionLayers.WORLD / PLAYER / ACTIONABLE` (nombres también en project.godot [layer_names]).
