# Capas de Tilemap y Orden en Z (Propuesta)

> Estado: **propuesta, pendiente de aprobación.** No se ha tocado ninguna escena, script ni la LevelApp.

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
| **Techos (filas 6-8)** | **`OverheadLayer`** |
| Muros, ventanas, puertas, cercas, barriles (filas 3-5, 9-12) | `PropsLayer` |
| Parte alta de arcos y portones (7:3, 8:3, 16:3, 17:3) | `OverheadLayer` |

Regla general: **lo que tiene colisión va en `PropsLayer`; lo que está por encima de la cabeza del jugador va en `OverheadLayer`.**

## 3. Cambios a implementar (tras aprobación)

### Escenas
- `level_01..03.tscn` (y los `*_nuevo` / `level_04..06`): `Environment.y_sort_enabled = true`, `z_index` por capa según la tabla, añadir `OverheadLayer` vacía.
- `level_03.tscn`: devolver `Player` a la raíz del nivel.
- Mover los tiles de copas/techos ya pintados de `PropsLayer` a `OverheadLayer` (script de una vez sobre `tile_map_data`, o a mano en el editor).
- `player.tscn` y `generic_enemy.tscn`: sin cambios de nodos; el y-sort usa su `position` (centro del cuerpo).

### Tileset (`core_tileset.tres`)
- Fuente `rpg_tiles_60`: `y_sort_origin` en la base de los troncos y objetos de `PropsLayer` para que el ordenamiento use el pie del objeto.

### LevelApp
- `public/index.html` (generador): añadir `OverheadLayer` (`z_index = 10`), `y_sort_enabled` en `Environment` y `z_index` en `GroundLayer`/`DetailLayer`; actualizar `layers` del spec y el texto de `instructions`.
- Test `tests/test_generate_scene.js`: comprobar la nueva capa.

### Documentación
- `design/Guia_Creacion_Niveles.md`, `design/Manual_Tecnico.md` y skill `godot-level-builder`: nueva capa y tabla de Z.

### Escena de prueba
- `src/overworld/levels/test_layers_z.tscn`: un árbol, una casa con techo y un arco; el jugador camina por detrás y por delante de cada uno.

## 4. Fuera de alcance (TODO en el Roadmap)
Organizar la posición en Z de **todos** los objetos de la escena (interactuables, efectos, proyectiles, minijuegos) queda como tarea del Backlog.
