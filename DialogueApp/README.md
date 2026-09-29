# DialogueApp — Editor Visual de Diálogos

Herramienta web local para crear, editar y guardar archivos `.dialogue` del proyecto RPG-G (Godot 4.6 + Dialogue Manager).

## Arranque

```bash
cd /home/diego/GameProjects/Gacheiducitos/DialogueApp
npm install   # solo la primera vez
npm start
```

Luego abre **http://localhost:3131** en el navegador.

## Funcionalidades

- **Canvas visual estilo Blueprint** — nodos arrastrables conectados con curvas Bézier
- **Tabs** — múltiples archivos `.dialogue` abiertos en paralelo
- **Parser/Serializer** — lee y escribe el formato `.dialogue` nativo de Dialogue Manager
- **Guardado directo** — escribe en `rpg-g/src/...` al hacer `Ctrl+S` o el botón Guardar
- **Sidebar** — gestión de variables narrativas (flags), lista de variables del sistema (solo lectura) y triggers del proyecto
- **Crear nuevos diálogos** — botón `+ Nuevo` con ruta personalizable

## Variables

El juego usa un sistema unificado de variables con rutas (`GameVariables`):

- `flag.<nombre>`: variables de historia. Se crean, renombran, borran y se les define tipo/valor inicial en la barra lateral (lectura y escritura). El nombre debe cumplir `^[a-z][a-z0-9_]*$`. Se guardan en `data/project_config.json` (una sola lista `variables`; las inválidas se descartan con aviso en consola del servidor) y generan `rpg-g/src/core/data/narrative_defaults.gd`.
- Solo lectura (`GET /api/system-variables`): `player.health`, `player.max_health`, `player.gold`, `player.speed`, `player.strength`, `player.resistance`, `item.<id>` (ids de `rpg-g/data/items/*.tres`), `status.<id>` (ids de `rpg-g/data/status_effects/*.tres`, si existe) y `quest.<id>` (`"active"`/`"completed"`/`""`, id libre en el selector de condiciones).
- Nodos de asignación: solo ofrecen `flag.*` y generan `do GameVariables.set_var("flag.nombre", valor)`.
- Nodos de condición: ofrecen `flag.*` + variables del sistema (agrupadas) y generan `if GameVariables.get_var("ruta") == valor` (operadores `== != > >= < <=`, y `elif` para switch).
- Los valores string van entre comillas; bool y números tal cual.
- Migración: al abrir un `.dialogue` antiguo con `NarrativeManager.get_flag/set_flag("x")` se lee como `flag.x`; al guardar queda escrito con la sintaxis nueva. Renombrar una flag actualiza solo las pestañas abiertas; los `.dialogue` cerrados no se reescriben.

## Atajos de teclado
 
| Tecla | Acción |
|---|---|
| `+` | Añadir nodo de diálogo |
| `V` | Añadir nodo de variable |
| `E` | Añadir nodo de evento |
| `F` | Ajustar y centrar vista (Fit View) |
| `Shift + Arrastrar` | Box selection (selección múltiple) |
| `Ctrl + C` / `Ctrl + V` | Copiar y pegar nodos seleccionados |
| `Supr` / `Backspace` | Eliminar nodos seleccionados |
| `Ctrl + S` | Guardar tab activo |
| `Escape` | Cerrar modal / deseleccionar |
| Rueda del ratón | Zoom del canvas |
| Arrastrar fondo | Pan del canvas |

> **Nota sobre Eventos:** Los nodos de evento generan `do GameManager.trigger_event(...)` en el archivo `.dialogue`. Está pendiente (marcado como TODO en `game_manager.gd`) conectar la señal en Godot cuando se requiera.

## Estructura de archivos

```
DialogueApp/
├── server.js           # Backend Express (puerto 3131)
├── package.json
├── data/
│   ├── project_config.json   # Variables (flags), actores, triggers
│   └── layouts/              # Posiciones de nodos por archivo
└── public/
    ├── index.html
    ├── style.css
    └── app.js
```

## Notas de seguridad

El servidor solo permite leer/escribir archivos dentro de `rpg-g/src/`. Cualquier intento de acceder a rutas fuera de ese directorio devuelve HTTP 403. Único añadido: `/api/system-variables` lee (solo lectura) los `.tres` de `rpg-g/data/items` y `rpg-g/data/status_effects` para obtener ids.
