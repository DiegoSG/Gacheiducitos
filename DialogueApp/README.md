# DialogueApp — Editor Visual de Diálogos

Herramienta web local para crear, editar y guardar archivos `.dialogue` del proyecto RPG-G (Godot 4.7 + Dialogue Manager 3).

## Arranque

```bash
cd DialogueApp   # desde la raíz del repositorio
npm install   # solo la primera vez
npm start
```

Luego abre **http://localhost:3131** en el navegador (el servidor solo escucha en `127.0.0.1`). `./run.sh` hace lo mismo y abre el navegador.

## Funcionalidades

- **Canvas visual estilo Blueprint** — nodos arrastrables conectados con curvas Bézier
- **Vista Escritura** — editor de guion con minimapa, autocompletado y creación de nodos mientras escribes (ver "Vistas")
- **Tabs** — múltiples archivos `.dialogue` abiertos en paralelo
- **Parser/Serializer** — lee y escribe el formato `.dialogue` nativo de Dialogue Manager sin perder datos (ver "Round-trip y nodos raw")
- **Guardado directo** — escribe en `rpg-g/src/...` al hacer `Ctrl+S` o el botón Guardar
- **Sidebar** — gestión de variables narrativas (flags) y lista de variables del sistema (solo lectura)
- **Crear nuevos diálogos** — botón `+ Nuevo` con ruta personalizable

## Variables

El juego usa un sistema unificado de variables con rutas (`GameVariables`):

- `flag.<nombre>`: variables de historia. Se crean, renombran, borran y se les define tipo/valor inicial en la barra lateral (lectura y escritura). El nombre debe cumplir `^[a-z][a-z0-9_]*$`. Se guardan en `data/project_config.json` (una sola lista `variables`; las inválidas se descartan con aviso en consola del servidor) y generan `rpg-g/src/core/data/narrative_defaults.gd`.
- Solo lectura (`GET /api/system-variables`): `player.health`, `player.max_health`, `player.gold`, `player.speed`, `player.strength`, `player.resistance`, `item.<id>` (ids de `rpg-g/data/items/*.tres`), `status.<id>` (ids de `rpg-g/data/status_effects/*.tres`, si existe) y `quest.<id>` (`"active"`/`"completed"`/`""`, id libre en el selector de condiciones).
- Nodos de asignación: solo ofrecen `flag.*` y generan `do GameVariables.set_var("flag.nombre", valor)`.
- Nodos de condición: ofrecen `flag.*` + variables del sistema (agrupadas) y generan `if GameVariables.get_var("ruta") == valor` (operadores `== != > >= < <=`, y `elif` para switch).
- Los valores string van entre comillas; bool y números tal cual.
- Migración: al abrir un `.dialogue` antiguo con `NarrativeManager.get_flag/set_flag("x")` se lee como `flag.x`; al guardar queda escrito con la sintaxis nueva. Renombrar una flag actualiza solo las pestañas abiertas; los `.dialogue` cerrados no se reescriben.

## Round-trip y nodos raw

Abrir y guardar un `.dialogue` sin tocarlo deja el archivo **idéntico byte a byte**:

- El texto previo al primer `~ ` (imports, `using`, comentarios) se conserva literal.
- Cada nodo recuerda su texto original y una huella de sus campos. Al guardar solo se reescriben los nodos que editaste o creaste; el resto se emite tal cual. No se reordenan nodos.
- Un nodo solo es editable en el canvas si usa sintaxis que el modelo representa fielmente: líneas `Actor: texto` o texto, `- opción => destino`, `=> destino`, `if cond` + una línea indentada (línea condicionada) o `=> destino` indentado (nodo condición, con `elif`), y un único `do GameVariables.set_var(...)` / `do GameManager.trigger_event("x")` (nodos variable/evento).
- Cualquier otra sintaxis (`else`, `set`, `%`, comentarios, tags `[#...]`, `[if ...]` inline, bloques indentados bajo opciones, varios `do`, etc.) convierte el nodo en **raw**: se muestra con borde punteado y su texto de solo lectura en el canvas, con las conexiones (punteadas) detectadas a partir de sus `=> destino`. Se edita como texto en el Inspector (al seleccionarlo) y se guarda exactamente como lo escribas. Renombrar otro nodo actualiza los destinos dentro de los nodos raw.
- Los nodos visuales START y END no se guardan como nodos. START apunta a `start` (si existe) o al primer nodo; si lo conectas a otro nodo y el archivo no tiene `~ start`, se agrega uno al principio. END representa `=> END`. Un `~ end` o `~ start` real del archivo es un nodo normal.
- Renombrar un nodo a un título ya existente se rechaza.

## Vistas: Escritura y Nodos

Cada pestaña tiene dos vistas a pantalla completa que **no comparten pantalla**. Se cambia con el selector del header o con `F1` / `F2` (se recuerda la última usada en `localStorage`). La barra lateral izquierda se colapsa con `Ctrl+B` en ambas vistas.

- **Nodos** (`F2`): el canvas de nodos con el inspector a la derecha.
- **Escritura** (`F1`): editor de guion con resaltado y números de línea. A la derecha, una columna estrecha (ocultable con `Alt+M`) con el **minimapa** del árbol (clic en un nodo = saltar a su `~ titulo`) y la **lista de nodos** (⚠ = aviso: destino inexistente, título duplicado o nodo sin salida).

Sincronización: al entrar en Escritura el texto se genera con el serializador (los nodos sin cambios salen idénticos). Mientras escribes, el texto es la fuente: con un debounce de ~300 ms se parsea y se reemplazan los nodos conservando posiciones x/y por título (los nodos nuevos aparecen 340 px a la derecha del primero que los referencia). Al volver a Nodos, el nodo donde estaba el cursor queda seleccionado y centrado; al ir a Escritura el cursor va al nodo seleccionado. `Ctrl+S` funciona en ambas vistas (en Escritura parsea antes de guardar). Abrir y guardar sin tocar nada deja el archivo idéntico.

### Escritura rápida

- `Enter` al final de `Actor: texto` crea la línea siguiente con `Actor: `; `Enter` sobre una línea que solo tiene `Actor: ` borra el prefijo.
- `Tab` al inicio de una línea de diálogo (o con solo el prefijo) alterna entre los dos últimos oradores; `Shift+Tab` inserta un tabulador.
- Autocompletado (flechas, `Enter`/`Tab`, `Esc`): oradores al empezar la línea, nodos tras `=> ` y variables dentro de `GameVariables.get_var("` / `set_var("`.
- `->` se convierte en `=>` (en líneas de opción `- ...` o al inicio de línea).
- Escribir `=> destino` o `- opción => destino` con un destino inexistente (al pulsar `Enter` o salir de la línea) añade al final un nodo `~ destino` con `=> END`. Una `- opción` sin destino + `Enter` se completa con `=> <nodo>_<opción>` y crea ese nodo.
- Al renombrar un `~ titulo` y salir de la línea, los `=> titulo` que apuntaban al nombre anterior se actualizan.
- Las inserciones usan el undo nativo del navegador (`Ctrl+Z`).

| Tecla (vista Escritura, foco en el editor) | Acción |
|---|---|
| `Ctrl+Enter` | Nodo nuevo a continuación del actual (enlaza la salida si no tenía) con el título seleccionado para renombrar |
| `Ctrl+O` | Opción `- ` (usa el texto seleccionado) |
| `Ctrl+I` | Condición `if GameVariables.get_var("") == true` + línea indentada |
| `Alt+V` | `do GameVariables.set_var("", true)` |
| `Alt+E` | `do GameManager.trigger_event("")` |
| `Ctrl+.` | `=> END` |
| `Ctrl+P` | Paleta: ir a un nodo por nombre |
| `F12` / `Ctrl+clic` en `=> x` | Saltar a `~ x` |
| `Alt+←` | Volver a la posición anterior |
| `Alt+M` | Mostrar/ocultar minimapa y lista |

## Atajos de teclado (generales y vista Nodos)

| Tecla | Acción |
|---|---|
| `F1` / `F2` | Vista Escritura / vista Nodos |
| `Ctrl + B` | Colapsar/mostrar la barra lateral |
| `Ctrl + S` | Guardar tab activo (ambas vistas) |
| `Escape` | Cerrar modal / deseleccionar |
| `+` | Añadir nodo de diálogo (solo vista Nodos) |
| `V` | Añadir nodo de variable (solo vista Nodos) |
| `E` | Añadir nodo de evento (solo vista Nodos) |
| `C` | Añadir nodo de condición (solo vista Nodos) |
| `F` | Ajustar y centrar vista (Fit View) |
| `Shift + Arrastrar` | Box selection (selección múltiple) |
| `Ctrl + C` / `Ctrl + V` | Copiar y pegar nodos seleccionados |
| `Supr` / `Backspace` | Eliminar nodos seleccionados |
| Doble clic en el cuerpo de un nodo / botón ✎ | Abrir ese nodo en la vista Escritura |
| `Enter` en el texto de una línea | Crea la línea siguiente y le da foco |
| Rueda del ratón | Zoom del canvas |
| Arrastrar fondo | Pan del canvas |

En la vista Nodos, los nodos nuevos (`+`, `V`, `E`, `C`) se colocan a la derecha del nodo seleccionado y se conectan desde él si no tenía salida. Soltar una conexión arrastrada en espacio vacío crea un nodo de diálogo nuevo ya conectado.

## Tests

```bash
npm test   # node tests/test_roundtrip.js
```

Comprueba el round-trip de todos los `.dialogue` de `rpg-g/src`, sintaxis rara, edición parcial, renombrado y líneas condicionadas.

> **Nota sobre Eventos:** Los nodos de evento generan `do GameManager.trigger_event(...)` en el archivo `.dialogue`. Está pendiente (marcado como TODO en `game_manager.gd`) conectar la señal en Godot cuando se requiera.

## Estructura de archivos

```
DialogueApp/
├── server.js           # Backend Express (puerto 3131, solo 127.0.0.1)
├── package.json
├── data/
│   ├── project_config.json   # Variables (flags)
│   └── layouts/              # Posiciones de nodos por archivo
├── tests/
│   └── test_roundtrip.js     # Tests de parser/serializer (sin dependencias)
└── public/
    ├── index.html
    ├── style.css
    ├── dialogue-format.js    # Parser/serializer (navegador y Node)
    ├── app.js                # Estado, canvas de nodos, pestañas, inspector
    └── writing.js            # Vista Escritura (editor, minimapa, autocompletado)
```

## Notas de seguridad

El servidor solo permite leer/escribir archivos `.dialogue` dentro de `rpg-g/src/`. Cualquier intento de acceder a rutas fuera de ese directorio devuelve HTTP 403. Único añadido: `/api/system-variables` lee (solo lectura) los `.tres` de `rpg-g/data/items` y `rpg-g/data/status_effects` para obtener ids.
