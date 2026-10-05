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
- Notas: `//texto//` = prompt a interpretar por un agente; el resto es información de diseño.

## Exportación manual

«Exportar levels_spec.json» y «PNG» descargan el spec y el mapa.
