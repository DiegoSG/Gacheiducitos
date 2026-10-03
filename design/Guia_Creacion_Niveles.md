# Guía Práctica: Creación de Niveles Overworld desde Cero (Vertical Slice)

> Para diseñar la planta (layout, tamaños, zonas, puntos de interés) ver `Guia_Plantas_de_Nivel.md`.

Esta guía paso a paso está diseñada para que cualquier desarrollador o diseñador de niveles pueda construir un nivel completamente funcional y conectado desde cero en **RPG-G (Godot 4.6)**.

---

## 1. Conceptos Fundamentales de la Escena de Nivel

Cada nivel de Overworld está compuesto por:
1. **`WorldBoundaryManager`**: Define el ancho y alto del mapa en píxeles, dibuja los límites en el editor y genera colisiones invisibles que impiden que el jugador se salga del mundo.
2. **`Environment`**: Agrupa las capas de `TileMapLayer` (`GroundLayer`, `DetailLayer`, `PropsLayer`) con la grilla oficial de **60x60 px**.
3. **`SpawnPoints`**: Contiene uno o más nodos `ArrivalSpawnPoint` con IDs únicos para saber dónde aterriza el jugador al entrar.
4. **`Player` + `BoundedCamera`**: La entidad del jugador con su cámara que respeta los límites del `WorldBoundaryManager`.
5. **Entidades & Triggers**: Puertas/Portales (`LevelPortal`), Enemigos (`GenericEnemy`), Cofres (`Chest`), Ítems en el suelo (`PickupItem`), NPCs (`SimpleNPC`) y Minijuegos (`minigame_interactable.tscn`).

---

## 2. Paso a Paso: Crear un Nuevo Nivel

### Paso 1: Duplicar la Plantilla Base
1. En el panel **FileSystem** (Archivos) de Godot, navega a `res://src/overworld/levels/`.
2. Haz clic derecho sobre `level_template.tscn` ➔ **Duplicate...** (o abre la escena y haz *Scene ➔ Save Scene As...*).
3. Nómbrala con la nomenclatura estándar en `snake_case`, por ejemplo: `level_forest_entrance.tscn` o `level_dungeon_room1.tscn`.
4. Abre tu nueva escena. En el árbol de nodos, cambia el nombre del nodo raíz al nombre de tu nivel.

### Paso 2: Configurar las Dimensiones del Nivel
1. Selecciona el nodo **`WorldBoundaryManager`**.
2. En el **Inspector**, ajusta:
   * **`Width`**: Ancho total en píxeles (ej. `3840` para 2 pantallas de 1920, o `1920` para 1 pantalla).
   * **`Height`**: Alto total en píxeles (ej. `2160` o `1080`).
3. Verás en la vista 2D del editor un recuadro azul cian que delimita el nivel exacto. La cámara del jugador (`BoundedCamera`) se ajustará automáticamente a estos valores al iniciar el juego.

### Paso 3: Pintar el Suelo y Obstáculos (`TileMapLayer`)
1. Despliega el nodo **`Environment`**. Encontrarás:
   * **`GroundLayer`**: Para el césped, tierra, pisos base.
   * **`DetailLayer`**: Para detalles sobre el suelo (flores, caminos, grietas).
   * **`PropsLayer`**: Para árboles, columnas, rocas con colisión. (Tiene `y_sort_enabled = true`).
2. Selecciona `GroundLayer` y abajo en la pestaña **TileMap** selecciona los tiles de `core_tileset.tres` (grilla 60x60). Pinta la superficie dentro del recuadro del `WorldBoundaryManager`.

### Paso 4: Colocar los Puntos de Llegada (`ArrivalSpawnPoint`)
1. En el nodo contenedor **`SpawnPoints`**, selecciona el nodo hijo `SpawnStart`.
2. Muévelo en la escena hacia la posición deseada de inicio.
3. En el **Inspector**, revisa su propiedad **`arrival_id`**:
   * Para el punto inicial por defecto: déjalo en `"start"`.
   * Para puntos provenientes de portales o minijuegos: asígnale un ID reconocible, como `"from_dungeon"`, `"from_runner_win"`, `"from_runner_lose"`.

### Paso 5: Colocar al Jugador
1. El nodo `Player` ya viene instanciado en la plantilla con su cámara hija `Camera2D` (`BoundedCamera`).
2. Colócalo sobre la misma posición que `SpawnStart`. (En runtime, si el jugador viene de un portal, `GameManager` reubicará al jugador automáticamente en el `ArrivalSpawnPoint` correspondiente).

---

## 3. Añadir Elementos Interactivos y Entidades

### A. Portales y Puertas (`LevelPortal`)
Para conectar tu nivel con otro mapa o habitación:
1. Arrastra `res://src/overworld/components/level_portal.tscn` a tu nivel.
2. Selecciónalo y configura en el **Inspector**:
   * **`Mode`**:
     * `PORTAL`: Se activa automáticamente cuando el jugador camina sobre él (ideal para cambios de mapa abiertos).
     * `DOOR`: El jugador debe pararse frente a él y pulsar la tecla de interacción `Espacio` / `E` / Botón A del Joystick.
   * **`Target Level Path`**: Selecciona el archivo `.tscn` del nivel al que viaja (ej. `res://src/overworld/levels/overworld.tscn`).
   * **`Exit Id`**: El `arrival_id` del punto del nivel destino donde aparecerá el jugador (ej. `"from_forest"`).
   * **`Arrival Id`**: El ID propio de este portal, para que otros portales puedan llegar a él.
3. **¿Quieres que la puerta esté cerrada con llave?**
   * En **`Key`**, arrastra el recurso `ItemData` de la llave (ej. `res://data/items/rusty_key.tres`). Asignarla marca la puerta como bloqueada.
   * Marca **`Consume Key`** si la llave debe desaparecer del inventario al usarse.
   * (Opcional) Asigna **`Locked Dialogue Resource`** / **`Locked Dialogue Title`** para mostrar un diálogo al intentar abrirla cerrada.

### B. Cofres con Recompensas (`Chest`)
1. Instancia `res://src/overworld/interactables/chest.tscn`.
2. En el **Inspector**:
   * **`Loot Items`**: Añade los recursos `ItemData` que otorgará al abrirse (ej. arrastra `res://data/items/red_potion.tres` o `gold_coins.tres`).
   * **`Is Storage Enabled`**: Déjalo en `false` si es solo un cofre de botín.

### C. Ítems en el Suelo (`PickupItem`)
1. Instancia `res://src/overworld/interactables/pickup_item.tscn`.
2. En el **Inspector**:
   * **`Item Data`**: Asigna el recurso del ítem (ej. `rusty_key.tres`). La textura, escala y colisionador se ajustarán automáticamente en el editor.
   * **`Custom Amount`**: Deja `-1` para cantidad por defecto o especifica un número (ej. `5` si son monedas).

### D. Enemigos con Patrulla y Loot (`GenericEnemy`)
1. Instancia `res://src/overworld/enemies/generic_enemy.tscn`.
2. Posiciónalo donde deba patrullar.
3. En el **Inspector**:
   * **`Speed`**: Velocidad de persecución (defecto `70.0`).
   * **`Max Health`**: Puntos de vida (defecto `3`).
   * Selecciona el nodo hijo **`LootDropComponent`** para configurar la tabla de recompensas:
     * En **`Drop Table`**, añade entradas con el recurso `ItemData` y el porcentaje de probabilidad (`Drop Chance` de 0.0 a 1.0).

### E. NPCs con Diálogo (`SimpleNPC`)
1. Instancia `res://src/overworld/npcs/npc_barnaby.tscn` (o crea un nodo `Area2D` con script `simple_npc.gd`).
2. En el **Inspector**:
   * **`Npc Name`**: Nombre a mostrar.
   * **`Dialogue Resource`**: Asigna el archivo de diálogo `.dialogue` (Dialogue Manager).
   * **`Dialogue Start Title`**: Título del nodo de diálogo inicial (ej. `"start"`).

### F. Minijuegos (`minigame_interactable.tscn`)
1. Instancia `res://src/overworld/interactables/minigame_interactable.tscn`.
2. En el nodo hijo **`GameTrigger`**, bajo **`Actions If True`**, edita el recurso **`MinigameAction`**:
   * Selecciona **`Minigame Type`** (`RUNNER`, `EXCAVATION`, `CATCHER`, etc.).
   * Configura las condiciones de victoria y dificultad deseadas.
   * Define **`Win Level Path`** / **`Win Spawn Id`** y **`Lose Level Path`** / **`Lose Spawn Id`**.

---

## 4. Checklist Rápido para Validar tu Nivel
- [ ] ¿El nodo raíz tiene un nombre descriptivo?
- [ ] ¿Los límites en `WorldBoundaryManager` abarcan todo el área jugable?
- [ ] ¿Existe al menos un `ArrivalSpawnPoint` con `arrival_id = "start"`?
- [ ] ¿Todos los portales tienen asignado un `target_level_path` válido y un `arrival_id` coincidente en el destino?
- [ ] ¿Los enemigos tienen su `LootDropComponent` configurado?
