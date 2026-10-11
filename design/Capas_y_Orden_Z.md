# Capas de Tilemap y Orden en Z

> Estado: **capas creadas** en los niveles de `src/overworld/levels/` y en el generador de la LevelApp. El reparto de tiles entre capas lo hace el usuario.

## 1. Problema

El jugador se dibuja encima de las copas de los árboles, techos y arcos: parece "pararse" sobre objetos que deberían taparlo.

Causas encontradas en las escenas actuales (`src/overworld/levels/`):

1. **`Environment` no tiene `y_sort_enabled`.** En Godot 4 el y-sort solo se propaga si *todos* los padres intermedios lo tienen activo. Como `Environment` es un `Node2D` normal, `PropsLayer` (aunque tenga `y_sort_enabled`) no se ordena contra `Player` ni `Entities`: todo `Environment` se dibuja como un bloque, antes que el jugador.
2. **Un objeto alto ocupa dos tiles en la misma capa.** En el atlas `rpg_tiles_60` los árboles son copa (fila 10) + tronco (fila 11). Ambos se pintan en `PropsLayer`, así que la copa se ordena por su propia fila y no por la base del árbol.
3. **`level_03`: `Player` quedó como hijo de `Environment/DetailLayer`** (copia local), así que se dibuja siempre debajo de `PropsLayer`.
4. **No hay convención de `z_index`.** Solo dos nodos de minijuegos lo usan.

## 2. Esquema propuesto

```text
LevelXX (Node2D, y_sort_enabled)
├── WorldBoundaryManager
├── Environment (Node2D, y_sort_enabled)          ← NUEVO: y_sort activo
│   ├── GroundLayer   (TileMapLayer, z_index = -2)   suelo, agua, caminos
│   ├── DetailLayer   (TileMapLayer, z_index = -1)   flores, grietas, sombras
│   ├── PropsLayer    (TileMapLayer, z_index = 0, y_sort_enabled)
│   │                  troncos, rocas, cercas, barriles, muros (con colisión)
│   └── OverheadLayer (TileMapLayer, z_index = 10)   ← NUEVA
│                      copas de árboles, techos, dinteles de arcos (sin colisión)
├── SpawnPoints
├── Entities (Node2D, y_sort_enabled)   enemigos, NPCs, cofres, pickups, triggers
├── Portals
└── Player   (z_index = 0, ordenado por y-sort con PropsLayer y Entities)
```

### Tabla de Z

| Banda | `z_index` | Qué va ahí |
|---|---|---|
| Suelo | -2 | `GroundLayer` |
| Detalle de suelo | -1 | `DetailLayer`, placas de presión, marcas en el piso |
| Mundo (y-sort) | 0 | `PropsLayer`, `Player`, `Entities`, `Portals` (se ordenan por Y entre sí) |
| Sobre el jugador | 10 | `OverheadLayer` (copas, techos, partes altas de arcos) |
| Efectos | 20 | partículas, golpes, textos flotantes |
| UI | `CanvasLayer` | HUD, diálogos, menús (fuera del `z_index`) |

### Regla de pintado (`rpg_tiles_60`)

| Tiles del atlas | Capa |
|---|---|
| Pasto, tierra, agua (filas 0-2) | `GroundLayer` |
| Arbustos pequeños (fila 9, columnas 0-5) | `PropsLayer` |
| **Copas de árboles (fila 10, columnas 0-5)** | **`OverheadLayer`** |
| Troncos (fila 11, columnas 0-5) | `PropsLayer` |
| Muros, techos, ventanas, puertas, cercas, barriles (filas 3-12) | `PropsLayer` |

Los techos (filas 6-8) tienen colisión en el tileset: son edificios sólidos vistos desde arriba, así que quedan en `PropsLayer` y el y-sort ya los dibuja sobre el jugador cuando pasa por detrás. Solo pasan a `OverheadLayer` si se pintan como alero transitable (sin colisión).

Regla general: **lo que tiene colisión va en `PropsLayer`; lo que está por encima de la cabeza del jugador va en `OverheadLayer`.**

## 3. Cambios aplicados

### Escenas (`src/overworld/levels/*.tscn`)
- `Environment` y `Portals`: `y_sort_enabled = true`.
- `GroundLayer` `z_index = -2`, `DetailLayer` `z_index = -1`.
- Nueva `OverheadLayer` (`z_index = 10`, `collision_enabled = false`) después de `PropsLayer`.
- No se movió ningún tile: `OverheadLayer` queda vacía y el reparto de copas/techos entre capas se hace a mano en el editor.
- `level_03.tscn` conserva su `z_index = 1` manual en `PropsLayer`; con el esquema nuevo debería volver a 0 para que el y-sort funcione con el jugador.
- `player.tscn` y `generic_enemy.tscn`: sin cambios; el y-sort usa su `position` (centro del cuerpo).

### LevelApp
- Generador (`public/index.html`): mismas capas y `z_index`; `layers` del spec incluye `OverheadLayer`.
- `tests/test_generate_scene.js`: comprueba el y-sort de `Environment`, los `z_index` y la nueva capa.

### Pendiente
- Escena de prueba `test_layers_z.tscn` (árbol, casa y arco para caminar por delante y por detrás).
- `y_sort_origin` por tile en `core_tileset.tres` si algún objeto alto necesita ordenarse por su base.

## 4. Fuera de alcance (TODO en el Roadmap)
Organizar la posición en Z de **todos** los objetos de la escena (interactuables, efectos, proyectiles, minijuegos) queda como tarea del Backlog.
