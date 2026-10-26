# Propuesta: Editor de niveles por TileMap para el minijuego de Excavación

> Estado: **propuesta, sin implementar**. Rama: `ExcavtionLevelEditor`.
> Alcance: cómo se *autora* un nivel. Las mecánicas (gravedad, empuje, bombas, excavación) **no cambian**.

---

## 1. Cómo está construido hoy

| Pieza | Archivo | Qué hace |
|---|---|---|
| Motor | `src/minigames/mg_excavation/mg_excavation_game.gd` | Hereda `MinigameBase`. Guarda el nivel en `grid: Array` (40×23 fijo, `CELL_SIZE = 16`), simula gravedad por ticks, dibuja todo con `_draw()` (primitivas + 3 texturas). |
| Generador | `level_generator.gd` | Autómata celular: ruido de tierra → suavizado → borde irrompible → zona de inicio 3×3 → rocas/bombas → monedas → ítems → ítem de misión → salida abajo a la derecha → flood fill (si falla, se llama recursivamente). |
| Tipos | `mg_excavation_types.gd` | `TileType` (13 valores, 3 sin uso: `MURO_ROMPIBLE` no se genera, `ENEMIGO` y `TRAMPA_BLOQUEO` no tienen lógica) y `WinCondition` (`ALL_COINS`, `TARGET_AMOUNT`, `SPECIFIC_ITEM`). |
| Entrada al juego | `src/core/pipeline/actions/minigame_action.gd` | Arma el `Dictionary` de config y llama `GameManager.load_minigame()`. |
| Debug | `src/minigames/tests/config_mg_excavation.gd` | Pantalla con sliders que llena el config a mano. |

Lo importante para el editor: **el motor sólo necesita un `grid` lleno y una posición de inicio**. Todo lo demás (gravedad, colisión, dibujo) ya lee de `grid`. Eso hace que cambiar la *fuente* del nivel sea barato y no toque la jugabilidad.

Acoplamientos que hay que soltar para soportar niveles hechos a mano:
- `grid_width`/`grid_height` fijos (40×23).
- `player_grid_pos` fijo en `(1, 1)`.
- La salida siempre es obligatoria; "sólo juntar monedas" no existe.
- `ITEM_INVENTARIO` siempre da un ítem al azar del `item_pool`; no se puede decir "en esta celda hay una `red_potion`".

---

## 2. Bugs y errores encontrados

Ordenados por impacto. Ninguno está corregido todavía (esta rama sólo trae la propuesta); los marco para decidir si van en la misma tanda que el editor.

| # | Severidad | Dónde | Problema | Cómo se reproduce |
|---|---|---|---|---|
| B1 | **Alta** (cuelgue) | `level_generator.gd:20` y `:131` | Con `seed` fijo, si el nivel sale sin camino a la salida, `generate_level()` se llama a sí mismo, vuelve a hacer `seed(seed_value)` y genera **exactamente el mismo mapa** → recursión infinita / stack overflow. | Config con un `seed` que produzca un mapa sin camino. |
| B2 | **Alta** (nivel imposible) | `mg_excavation_game.gd:239` | Una explosión borra monedas (`ITEM_RECOMPENSA`) y el ítem de misión, pero `total_coins` no baja. Con `ALL_COINS` o `SPECIFIC_ITEM` el nivel queda **imposible de ganar** y sólo queda abandonar. | Volar una moneda con una bomba en modo "todas las monedas". |
| B3 | **Alta** (nivel imposible) | `level_generator.gd:75-80`, `mg_excavation_game.gd:103` | El generador salta las monedas que no tienen apoyo debajo (el `num_monedas += 1` no alarga el `range`, que ya se evaluó), así que suelen salir **menos de 10**. `target_amount` nunca se limita a las monedas reales: con `TARGET_AMOUNT = 10` puede no haber 10 monedas. | Disparar el minijuego desde un `MinigameAction` con `excavation_target_amount` alto. |
| B4 | Media | `minigame_action.gd:428` | `excavation_rocks` se envía como `"rocks"`, pero el generador lee `"probabilidad_piedra"`. **La opción del inspector no hace nada.** Además `num_monedas` no está expuesto en `MinigameAction`, así que desde el juego siempre se piden 10 monedas. | Cambiar `excavation_rocks` a 0 o 30: el mapa sale igual. |
| B5 | Media | `mg_excavation_game.gd:465-478` + pausa | `input_stack` sólo se actualiza en `_input`, que no corre con el árbol pausado. Si se suelta una flecha mientras está abierto el menú de pausa, al reanudar **el personaje sigue caminando solo** en esa dirección. | Mantener → , abrir pausa, soltar →, reanudar. |
| B6 | Baja | `mg_excavation_game.gd:212-220` | Cuando explota una bomba manual, `_explode_at` saca de `active_placed_bombs` las bombas manuales vecinas, pero `_update_placed_bombs` después pisa la lista con `remaining` (armada con la lista vieja) y **las vuelve a poner**. Resultado: bombas manuales vecinas no se desactivan ni encadenan; explotan después por su cuenta. | Plantar dos bombas en celdas contiguas. |
| B7 | Baja (visual) | `mg_excavation_game.gd:328-333` | El tinte rojo de muerte se dibuja **antes** del fondo, que lo tapa por completo. Nunca se ve. | Morir aplastado. |
| B8 | Baja | `level_generator.gd:21` | `seed()` cambia el RNG **global**; después del minijuego, todo lo demás que use `randi()`/`randf()` queda determinista. Mejor un `RandomNumberGenerator` propio. | Config con `seed` fijo. |
| B9 | Duda de diseño | `mg_excavation_game.gd:757-768` | Una **moneda** que cae sobre el jugador lo mata (va por la misma rama que la roca). En Boulder Dash es así, pero hay que confirmar si lo querés. | Cavar debajo de una moneda apoyada. |

Ruido menor (no son bugs): `world_to_grid()` sin uso, `TileType.ENEMIGO`/`TRAMPA_BLOQUEO` sin lógica, la variable `_reason` se usa aunque tenga prefijo `_`, varias variables sin tipado estático (las reglas del proyecto lo piden).

---

## 3. ¿Funciona el concepto de pintar con TileMap? Alternativas evaluadas

Requisitos: pintar rápido, ver el nivel tal como se juega, poner ítems por tile o a mano, que el juego "entienda" los tiles, y que el minijuego sólo defina la condición de victoria.

| Opción | Cómo sería | A favor | En contra |
|---|---|---|---|
| **A. `TileMapLayer` en una escena por nivel** | `exc_level_xx.tscn` con un `TileMapLayer` pintado con un `TileSet` cuyo *custom data layer* `excavation_tile` dice qué es cada tile. Un loader lo convierte al `grid` actual. | Herramientas de pintura de Godot gratis (lápiz, rectángulo, balde, patrones). WYSIWYG. Sin herramienta nueva que mantener. Warnings en el editor con `@tool`. Los niveles son archivos versionables. | El `tile_map_data` de la escena es binario (los diffs en git no se leen). Hay que mantener el TileSet sincronizado con `TileType`. |
| B. Un nodo por objeto (rocas, monedas como escenas) | Instanciar escenas en una grilla. | Flexible. | Cientos de nodos por nivel; lento de editar; no aporta nada que el grid no tenga. **Descartada.** |
| C. `Resource` de datos (`.tres` con `PackedInt32Array`) | El nivel es un array de enteros + metadatos. | Compacto, diffs legibles, carga trivial. | No se puede pintar en Godot sin un plugin propio (mucho trabajo). |
| D. Modo "excavación" en LevelApp | Una grilla en `LevelApp/public/index.html` que exporta el nivel. | Una sola herramienta para todos los niveles, coherente con "LevelApp crea los niveles". | Hay que construir el pintor desde cero en JS (balde, rectángulo, deshacer…) y mantenerlo; el `tile_map_data` binario de Godot es incómodo de generar desde JS. |

**Recomendación: A (TileMapLayer en Godot), con un formato intermedio compatible con C.**

El loader no lee el TileMap directo en el motor, sino que produce un objeto de datos (`ExcavationLevelData`: tamaño, grid, inicio, ítems por celda). Así:
- El motor sólo conoce `ExcavationLevelData`, venga del TileMap, del generador procedural o, en el futuro, de LevelApp.
- Si más adelante querés que LevelApp sea la fuente única, LevelApp exporta ese mismo formato (un `.tres` o JSON) y no hay que tocar el motor. Hoy no lo recomiendo porque es mucho más trabajo que reaprovechar el pintor de Godot.
- LevelApp sí puede, desde ya, apuntar el minijuego del overworld a un nivel concreto (agregar una propiedad `excavation_level` a la entidad `minigame`).

Una nota sobre tu regla de "LevelApp crea los niveles": esa regla la tengo registrada para niveles del **overworld**. Los niveles del minijuego los pintarías vos en Godot; no sería yo creando niveles a mano. Si preferís que todo pase por LevelApp, la opción D sigue abierta gracias al formato intermedio.

---

## 4. Diseño propuesto (opción A)

### 4.1 Escenas y scripts

**Nuevos** (todos en `src/minigames/mg_excavation/`, salvo el TileSet):

| Archivo | Tipo | Responsabilidad |
|---|---|---|
| `excavation_level.gd` | `@tool`, `class_name ExcavationLevel extends Node2D` | Raíz de cada nivel pintado. Exporta opciones del nivel y muestra warnings en el editor (`_get_configuration_warnings`): sin inicio, sin salida, salida inalcanzable, borde abierto, más de un inicio. |
| `excavation_item_marker.gd` | `@tool`, `class_name ExcavationItemMarker extends Node2D` | Ítem "a mano": se arrastra en el editor, se encaja a la celda más cercana y define un ítem concreto. |
| `excavation_level_data.gd` | `class_name ExcavationLevelData extends RefCounted` | Datos puros del nivel: `size`, `grid`, `player_start`, `cell_items`. |
| `excavation_level_loader.gd` | `class_name ExcavationLevelLoader` (funciones `static`) | `TileMapLayer` + marcadores → `ExcavationLevelData`. Función pura, fácil de testear. |
| `levels/` | carpeta | Aquí van tus niveles (`exc_level_01.tscn`, …). No creo ninguno. |
| `assets/sprites/excavation_tileset.tres` | `TileSet` | Atlas placeholder de 16×16 + custom data layer `excavation_tile: int` (valor de `TileType`). Al lado de `core_tileset.tres`. |

**Modificados:**

| Archivo | Cambio |
|---|---|
| `mg_excavation_types.gd` | Agregar `PLAYER_START` al final de `TileType` (sólo existe en el editor; el loader lo convierte en `EMPTY` + posición de inicio). Agregar `EXIT_ONLY` al final de `WinCondition`. Al final, para no romper valores guardados en `.tres`/`.tscn`. |
| `mg_excavation_game.gd` | `_generate_level()` pasa a pedir un `ExcavationLevelData` (escena si `config.level_scene` existe, si no el generador). Toma `grid_width/height` y `player_grid_pos` de los datos. `_collect_tile` usa `cell_items[pos]` si existe antes de caer al `item_pool`. Nueva regla de victoria (4.4). **Gravedad, empuje, bombas y dibujo no se tocan.** |
| `level_generator.gd` | Devuelve `ExcavationLevelData` (inicio `(1,1)`, como hoy). De paso se arreglan B1, B3 y B8. |
| `minigame_action.gd` | Nuevas propiedades de excavación: `excavation_level_scene` (archivo `*.tscn`, vacío = procedural) y `excavation_require_exit`. Arreglar B4. |
| `design/Minigames_Guide.md` | Documentar el flujo de pintado. |

### 4.2 Cómo se reconocen los tiles

Cada tile del TileSet lleva el custom data `excavation_tile` con el valor de `TileType`. El loader hace:

```gdscript
static func from_tile_layer(layer: TileMapLayer, markers: Array[ExcavationItemMarker]) -> ExcavationLevelData:
	var rect: Rect2i = layer.get_used_rect()
	var data := ExcavationLevelData.new()
	data.size = rect.size
	data.grid = _empty_grid(rect.size)
	for cell: Vector2i in layer.get_used_cells():
		var tile_data: TileData = layer.get_cell_tile_data(cell)
		var tile_type: int = tile_data.get_custom_data("excavation_tile")
		var local: Vector2i = cell - rect.position
		if tile_type == TileType.PLAYER_START:
			data.player_start = local
		else:
			data.grid[local.y][local.x] = tile_type
	for marker: ExcavationItemMarker in markers:
		var local: Vector2i = layer.local_to_map(marker.position) - rect.position
		data.grid[local.y][local.x] = TileType.ITEM_INVENTARIO
		data.cell_items[local] = marker.item_id
	return data
```

Ventajas de usar custom data y no coordenadas del atlas: podés cambiar el arte, tener varias variantes visuales de "tierra" o de "muro" y el juego sigue entendiendo qué es cada una. Celdas sin pintar = `EMPTY`.

### 4.3 Ítems: por tile o a mano

- **Por tile** (rápido, para cantidad): tiles de moneda, pickup de bomba, ítem de misión e "ítem aleatorio" (`ITEM_INVENTARIO`, sale del `item_pool`, igual que hoy).
- **A mano** (para algo concreto): un `ExcavationItemMarker` hijo de `Items`, con:
  - `@export var item_id: String` — "Item id from ItemDatabase given when the cell is collected."
  - `@export var amount: int = 1` — "How many units are added to the session rewards."
  - En el editor se encaja a la grilla y muestra el ícono del ítem (`MinigameBase.get_item_icon`). Si el `item_id` no existe en `ItemDatabase`, warning.

Estructura de una escena de nivel:

```
ExcavLevel01 (ExcavationLevel)
├── Terrain (TileMapLayer, tile_set = excavation_tileset.tres)
└── Items (Node2D)
    ├── RedPotion (ExcavationItemMarker)
    └── AncientMap (ExcavationItemMarker)
```

Propiedades exportadas de `ExcavationLevel` (en inglés, como pide la regla):
- `auto_border: bool = true` — "Wraps the painted area with unbreakable walls so the player can never leave the grid."
- `item_pool: Array[String] = []` — "Overrides the minigame item pool for random item tiles. Empty uses the action's pool."

### 4.4 La condición de victoria vive en el minijuego, no en el nivel

El nivel sólo define el **mapa**. El `MinigameAction` (o el config) define cómo se gana, así el mismo nivel sirve para misiones distintas:

| Lo que pediste | Configuración |
|---|---|
| Juntar monedas | `win_condition = ALL_COINS` o `TARGET_AMOUNT`, `require_exit = false` → gana al juntar la última. |
| Llegar al final | `win_condition = EXIT_ONLY` → la salida está abierta desde el inicio. |
| Ambas | `win_condition = ALL_COINS`/`TARGET_AMOUNT`/`SPECIFIC_ITEM`, `require_exit = true` (default, es el comportamiento actual). |

`require_exit` en el inspector: "If true, the player must reach the exit after meeting the goal. If false, the minigame is won as soon as the goal is met."

Validaciones al cargar (con `push_warning`, no bloquean): `target_amount` mayor que las monedas del nivel → se limita al total (arregla B3 también para niveles pintados); `SPECIFIC_ITEM` sin ítem de misión; `EXIT_ONLY` o `require_exit` sin salida.

### 4.5 Flujo de datos

```
MinigameAction (level_scene, win_condition, require_exit)
   └─► GameManager.minigame_config
         └─► MG_ExcavationGame._ready()
               ├─ level_scene vacío → LevelGenerator.generate_level() ─┐
               └─ level_scene       → instanciar escena (sin agregarla ├─► ExcavationLevelData
                                      al árbol) → ExcavationLevelLoader ┘        │
                                                                                  ▼
                                  grid / grid_width / grid_height / player_grid_pos / cell_items
                                  (a partir de acá todo igual que hoy)
```

No hay señales nuevas ni autoloads nuevos. La escena del nivel se instancia sólo para leerla y se libera (`free()`); el dibujo sigue siendo el `_draw()` actual.

### 4.6 Arte (fase posterior, opcional)

Hoy el motor dibuja primitivas. Pintar con el TileSet te da arte en el editor, pero en juego se seguiría viendo con `_draw()`. Si después querés que el juego use el mismo arte del TileMap, la fase 2 sería dibujar las celdas estáticas (tierra, muros, salida) con un `TileMapLayer` en runtime y actualizarlo con `set_cell` al cavar/explotar, dejando rocas/monedas/bombas con el dibujo animado actual. No es necesario para el editor.

---

## 5. Pruebas

- Sin niveles de prueba (regla del proyecto). Vos hacés el QA con tus propios niveles.
- Unidad chica posible: un runner que arme un `TileMapLayer` 4×3 en código y compruebe que `ExcavationLevelLoader` devuelve el grid, el inicio y los ítems correctos; y otro para el límite de `target_amount`. No lo corro yo con Godot headless (el binario 4.6 reescribe `project.godot`); queda para que lo ejecutes con 4.7 si querés.

**Pasos de QA manual sugeridos** (cuando esté implementado):
1. Crear `levels/exc_level_01.tscn` con raíz `ExcavationLevel`, pintar tierra, rocas, 3 monedas, inicio y salida.
2. En un `MinigameAction`, poner `excavation_level_scene` = ese nivel, `ALL_COINS`, `require_exit = true` → hay que juntar las 3 y salir.
3. Mismo nivel con `require_exit = false` → gana al tomar la tercera moneda.
4. Mismo nivel con `EXIT_ONLY` → la salida abre de entrada.
5. Agregar un `ExcavationItemMarker` con `red_potion` → al cavarlo se recibe exactamente eso.
6. Borrar el inicio o la salida → el editor muestra el warning en el nodo raíz.
7. Dejar `excavation_level_scene` vacío → sigue saliendo el nivel procedural.

---

## 6. Plan de implementación (cuando lo apruebes)

1. Fixes B1–B8 (y B9 según lo que decidas), en commits `fix(excavation): …` separados.
2. `ExcavationLevelData` + refactor del generador para devolverlo (sin cambio de comportamiento).
3. Loader + `ExcavationLevel` + `ExcavationItemMarker` + TileSet placeholder.
4. Condición de victoria (`EXIT_ONLY`, `require_exit`) y propiedades en `MinigameAction`.
5. Documentación en `Minigames_Guide.md` y checklist.

## 7. Decisiones que necesito de vos

1. **¿TileMap en Godot (A, recomendado) o modo excavación en LevelApp (D)?**
2. **B9:** ¿una moneda que cae sobre el jugador lo mata, o debería recogerse?
3. **B2:** cuando una explosión destruye monedas, ¿descontarlas del total (el nivel sigue ganable) o es castigo intencional? Recomiendo descontarlas y dejar el ítem de misión inmune a explosiones, como la salida.
4. ¿Los fixes van en esta misma rama o aparte?
