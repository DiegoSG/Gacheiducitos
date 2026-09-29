---
name: dialogue-app-bridge
description: Flujo técnico entre DialogueApp (editor web), archivos .dialogue, NarrativeDefaults, NarrativeManager y GameManager.trigger_event en RPG-G. Usar al conectar diálogos con eventos/flags o modificar DialogueApp.
---

# Skill: Puente DialogueApp ↔ Godot (RPG-G)

## 1. Límite de rol
La IA **no escribe líneas de diálogo, nombres ni lore**. Solo estructura: nodos, flags, eventos, conexiones y placeholders marcados (`TODO: texto del usuario`).

## 2. DialogueApp (`DialogueApp/`)
- Node/Express, puerto 3131: `cd DialogueApp && npm start`. Solo lee/escribe dentro de `rpg-g/src/` (resto → 403); mantener esa restricción.
- `server.js` (backend), `public/app.js` (canvas, parser/serializer `.dialogue`), `data/project_config.json` (actores, flags, triggers), `data/layouts/` (posiciones de nodos).
- Al guardar variables, el backend regenera `rpg-g/src/core/data/narrative_defaults.gd` (**archivo generado: no editar a mano**, cambiar la fuente en `project_config.json`/app).

## 3. Lado Godot
- Addon `Dialogue Manager` (`rpg-g/addons/dialogue_manager/`), autoload `DialogueManager`.
- Flags: `NarrativeManager.get_flag("x")` / `set_flag("x", v)`; defaults cargados de `NarrativeDefaults.DEFAULTS`.
- Eventos: nodos de evento generan `do GameManager.trigger_event("Nombre")` → señal `GameManager.game_event` → la escuchan `DialogueEvent` (por `name` o `event_id`) u `OnEventListener` (→ `GameTrigger.force_trigger()`).
- Diálogos desde el pipeline: `DialogueAction`; NPC simple: `SimpleNPC.dialogue_resource` + `dialogue_start_title`.

## 4. Checklist al conectar un evento
1. El nombre del evento en el `.dialogue` coincide exactamente con el `DialogueEvent`/`OnEventListener` del nivel.
2. Flags usadas existen en `project_config.json` (y por tanto en `NarrativeDefaults`).
3. Si el evento debe ocurrir una vez: `one_shot` + `persistence_id`.
4. Verificar con `test_dialogue_events_runner.gd` (skill `godot-headless-test`).
