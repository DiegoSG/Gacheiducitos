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
- **Sidebar** — gestión de actores, variables narrativas (flags) y triggers del proyecto
- **Crear nuevos diálogos** — botón `+ Nuevo` con ruta personalizable

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
│   ├── project_config.json   # Actores, flags, triggers
│   └── layouts/              # Posiciones de nodos por archivo
└── public/
    ├── index.html
    ├── style.css
    └── app.js
```

## Notas de seguridad

El servidor solo permite leer/escribir archivos dentro de `rpg-g/src/`. Cualquier intento de acceder a rutas fuera de ese directorio devuelve HTTP 403.
