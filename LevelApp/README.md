# LevelApp — Editor Visual de Niveles

Herramienta web local para diseñar el mundo del overworld de RPG-G (niveles, portales, spawns, minijuegos, enemigos, NPC, cofres y notas) y generar las escenas `.tscn`. Mismo esquema que `DialogueApp`: el servidor conoce las rutas del proyecto, no hay que indicarlas.

## Arranque

```bash
cd /home/diego/GameProjects/Gacheiducitos/LevelApp
./run.sh        # o: npm start
```

Abre **http://localhost:3132** (sin dependencias: solo Node).

## Archivos

| Ruta | Contenido |
|---|---|
| `public/index.html` | La app (canvas + generador de escenas) |
| `server.js` | Servidor local: guarda el proyecto y escribe las escenas |
| `data/levelapp_proyecto.json` | Proyecto guardado automáticamente |
| `tests/` | `test_generate_scene.js` + `sample_levels_spec.json` (`npm test`) |

## Botón «Generar niveles»

- Escribe un `.tscn` por nivel en `rpg-g/src/overworld/levels/` y las notas/prompts en `design/Level_Prompts.md`.
- **Nunca sobrescribe**: si un nivel ya existe, pide un nombre nuevo para ese nivel.
- No genera si el validador tiene errores.
- Cada escena incluye `WorldBoundaryManager`, capas, `SpawnPoints`, portales, entidades, `Player` en el start y `SceneMusic` sin música asignada.
- Diálogos: cada NPC y cada Trigger tienen un campo **Diálogo** con los `.dialogue` de `rpg-g/src` o «Nuevo (proxy)». Al generar, si el archivo existe se asigna; si no, se crea un proxy (`~ start` + línea pendiente + `=> END`, por defecto en `rpg-g/src/overworld/dialogues/<nivel>_<objeto>.dialogue`) y se asigna. Nunca se sobrescribe un `.dialogue` existente.
- Notas: `//texto//` = prompt a interpretar por un agente; el resto es información de diseño.

## Trigger (G)

Un objeto Trigger tiene un **Tipo**, que elige la escena del juego, y su diálogo se ejecuta como `DialogueAction` cuando se activa:

| Tipo | Escena | Se activa | Acciones donde va el diálogo |
|---|---|---|---|
| Área | `interactables/game_trigger_area.tscn` (`GameTrigger`) | al pisar, al salir, al interactuar o al cargar el nivel | `actions_if_true` |
| Placa de presión | `interactables/pressure_plate.tscn` | al pisarla | `on_enter_actions` |
| Palanca / interruptor | `interactables/switch_interactable.tscn` | al encenderla | `trigger_actions` |
| Evento remoto | `interactables/dialogue_event.tscn` | con `do GameManager.trigger_event("event_id")` desde otro diálogo | `actions` |

«Una vez» se traduce a `one_shot` (en la palanca, a `is_toggleable = false`). Cada trigger lleva `persistence_id = <nivel>_<id>`.

## Exportación manual

«Exportar levels_spec.json» y «PNG» descargan el spec y el mapa.
