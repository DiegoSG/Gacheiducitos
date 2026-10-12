# Capas de Tilemap y Orden en Z

## 1. Problema original

El jugador se dibujaba encima de árboles, techos y arcos porque `Environment` no tenía `y_sort_enabled`: en Godot 4 el y-sort solo se propaga si todos los padres intermedios lo tienen activo, así que `PropsLayer` no se ordenaba contra `Player` ni `Entities`.

## 2. Estructura de capas

```text
LevelXX (Node2D, y_sort_enabled)
├── WorldBoundaryManager
├── Environment (Node2D, y_sort_enabled)
│   ├── GroundLayer   (TileMapLayer, z_index = -2, collision_enabled = false)
│   ├── DetailLayer   (TileMapLayer, z_index = -1, collision_enabled = false)
│   ├── PropsLayer    (TileMapLayer, z_index = 0, y_sort_enabled)   ← única capa con colisión
│   └── OverheadLayer (TileMapLayer, z_index = 10, collision_enabled = false)
├── SpawnPoints
├── Entities (Node2D, y_sort_enabled)
├── Portals  (Node2D, y_sort_enabled)
└── Player
```

| Banda | `z_index` | Qué va ahí |
|---|---|---|
| Suelo | -2 | `GroundLayer` |
| Detalle de suelo | -1 | `DetailLayer` |
| Mundo (y-sort) | 0 | `PropsLayer`, `Player`, `Entities`, `Portals` (se ordenan por Y entre sí) |
| Sobre el jugador | 10 | `OverheadLayer` |
| UI | `CanvasLayer` | HUD, diálogos, menús |

## 3. Reglas

- **Colisión:** se controla por tile con la **Physics Layer 0** de `core_tileset.tres`. Solo `PropsLayer` la usa; `GroundLayer`, `DetailLayer` y `OverheadLayer` tienen `collision_enabled = false`, así que nada pintado en ellas bloquea aunque el tile tenga colisión.
- **Árboles:** copa y tronco van juntos en la misma capa (no se separan).
- **Qué tile va en qué capa:** lo decide quien diseña el nivel; no hay regla automática ni script que mueva tiles.

## 4. Implementación

- Escenas `src/overworld/levels/*.tscn`: `Environment` y `Portals` con y-sort, `z_index` y `collision_enabled` según la tabla, `OverheadLayer` creada vacía. No se movió ningún tile.
- LevelApp (`public/index.html`): el generador crea las mismas capas; `tests/test_generate_scene.js` lo comprueba.

## 5. Pendiente (Roadmap)

Organizar la posición en Z de **todos** los objetos de la escena (interactuables, efectos, proyectiles, minijuegos).
