# Manual de Minijuegos y Guía de Configuración (Game Design)

Este documento es la referencia oficial para diseñadores de niveles y programadores. Aquí se detallan los modos de victoria, parámetros configurables, controles y claves de datos de todos los minijuegos de RPG-G.

---

## 1. Cómo Lanzar un Minijuego en el Mapa

Para colocar un acceso a un minijuego en cualquier nivel del Overworld:
1. Instancia el prefab reutilizable **`res://src/overworld/interactables/minigame_interactable.tscn`** (o añade un nodo `GameTrigger`).
2. En el Inspector del trigger, bajo **`Actions If True`**, añade un recurso **`MinigameAction`**.
3. En el desplegable **`Minigame Type`**, selecciona el minijuego deseado. El inspector mostrará automáticamente las opciones dedicadas para ese juego.
4. Configura las rutas de retorno:
   * **`Win Level Path`** y **`Win Spawn Id`**: A dónde vuelve el jugador si gana.
   * **`Lose Level Path`** y **`Lose Spawn Id`**: A dónde vuelve si pierde.

---

## 2. Catálogo de Minijuegos y Modos de Victoria

---

### 🏃 1. Minijuego RUNNER (`MG_Runner`)
**Escena:** `res://src/minigames/mg_runner/mg_runner_level.tscn`  
**Estilo:** Side-scroller 2D lateral con salto, agache/slide y disparo frontal.

#### Modos de Victoria (`runner_win_mode` / `win_condition`)
| Valor Numérico | Nombre en Inspector | Descripción | Parámetro Requerido |
| :---: | :--- | :--- | :--- |
| **`0`** | **Por Distancia (Metros)** | El jugador gana al recorrer la distancia objetivo especificada en metros. | `runner_target_distance` (ej. `1500.0`) |
| **`1`** | **Por Objeto Clave (Meta)** | En un punto aleatorio dentro de un rango de distancia, aparece un ítem brillante que otorga la victoria inmediata al recogerlo. | `runner_target_item_id` (ej. `"ancient_map"`) y `runner_target_distance_range` (ej. `Vector2(800.0, 1200.0)`) |

#### Parámetros Configurables del Inspector
* **`runner_speed`** *(float)*: Velocidad de avance de la pista en píxeles/segundo (defecto: `380.0`).
* **`runner_coin_density`** *(float)*: Probabilidad (de `0.0` a `1.0`) de que aparezcan patrones de monedas (defecto: `0.55`).
* **`runner_max_coins`** *(int)*: Cantidad máxima de monedas que pueden aparecer en la partida (`-1` = sin límite).
* **`runner_item_pool`** *(Array[String])*: Lista de IDs de ítems secundarios que pueden aparecer flotando en la pista para sumarse al inventario (ej. `["blue_potion", "red_potion", "green_herb"]`).

#### Patrones de Monedas Generados
* **Líneas de 1, 2, 3 o 4 monedas:** Generadas a ras de carrera horizontal ($Y = 765$).
* **Patrón en V:** Valle de monedas altas en los extremos y bajas en el centro.
* **Patrón en V Invertida:** Arco parabólico de 5 monedas diseñado para guiar y premiar el salto sobre obstáculos terrestres.

#### Controles del Jugador
* **Saltar:** `ESPACIO`, `FLECHA ARRIBA` o `W` (impulso de salto con física parabólica y cola de salto anticipada).
* **Agacharse / Deslizarse:** `FLECHA ABAJO` o `S` (reduce el colisionador de 115 px a 52 px para pasar limpio bajo obstáculos aéreos).
* **Caída Rápida (*Fast-Fall*):** Presionar abajo mientras estás en el aire acelera la gravedad para aterrizar de inmediato.
* **Disparar:** Tecla `Z` (destruye muros y enemigos frontales si tienes munición).

---

### ⛏️ 2. Minijuego EXCAVACIÓN (`MG_Excavation`)
**Escena:** `res://src/minigames/mg_excavation/mg_excavation_game.tscn`  
**Estilo:** Grid 2D de excavación procedural con gravedad de rocas (estilo *Boulder Dash / Supaplex*).

#### Modos de Victoria (`excavation_win_condition` / `win_condition`)
| Valor Numérico | Nombre en Inspector | Descripción | Parámetro Requerido |
| :---: | :--- | :--- | :--- |
| **`0`** | **Todas las Monedas** | Recolectar el 100% de las monedas generadas en todo el mapa de tierra. | Ninguno (automático). |
| **`1`** | **Cantidad Específica** | Alcanzar un número determinado de monedas para abrir la salida. | `excavation_target_amount` (ej. `10`). |
| **`2`** | **Ítem de Misión** | Desenterrar y recoger un ítem de misión especial escondido en el nivel. | Objeto de misión en mapa. |

#### Parámetros Configurables del Inspector
* **`excavation_rocks`** *(int)*: Cantidad o densidad de rocas que caen por gravedad (defecto: `10`).
* **`excavation_scale`** *(float)*: Multiplicador de escala visual del mapa (defecto: `1.5`).

---

### 🧺 3. Minijuego CATCHER (`MG_Catcher`)
**Escena:** `res://src/minigames/mg_catcher/mg_catcher_game.tscn`  
**Estilo:** Recolección de objetos caídos evitando bombas o penalizadores.

#### Modos de Juego / Victoria (`catcher_game_mode` / `game_mode`)
| Valor | Nombre en Inspector | Descripción | Parámetro Requerido |
| :---: | :--- | :--- | :--- |
| **`0`** (`COUNT`) | **Puntos Objetivo** | Ganar al acumular la cantidad requerida de puntos/objetos. | `catcher_target_value` (ej. `10.0`). |
| **`1`** (`TIME`) | **Sobrevivir Tiempo** | Ganar resistiendo con vida hasta que el temporizador llegue a cero. | `catcher_target_value` (ej. `30.0` segundos). |

#### Parámetros Configurables del Inspector
* **`catcher_lives`** *(int)*: Vidas del jugador antes de perder (defecto: `3`).
* **`catcher_fall_speed`** *(float)*: Velocidad vertical de los objetos que caen (defecto: `200.0`).
* **`catcher_spawn_rate`** *(float)*: Segundos entre cada oleada de objetos (defecto: `0.8`).
* **`catcher_max_objects`** *(int)*: Límite de objetos simultáneos en pantalla (defecto: `8`).

---

### 🔨 4. Minijuego SMASHER (`MG_Smasher`)
**Escena:** `res://src/minigames/mg_smasher/mg_smasher_game.tscn`  
**Estilo:** Golpeador de insectos/dianas emergentes con reflejos rápidos.

#### Modos de Juego / Victoria (`smasher_game_mode` / `game_mode`)
| Valor | Nombre en Inspector | Descripción | Parámetro Requerido |
| :---: | :--- | :--- | :--- |
| **`0`** (`COUNT`) | **Dianas Golpeadas** | Ganar al aplastar un número meta de objetivos. | `smasher_target_value` (ej. `15.0`). |
| **`1`** (`TIME`) | **Tiempo Límite** | Mantener el ritmo durante los segundos indicados. | `smasher_target_value` (ej. `25.0` segundos). |

#### Parámetros Configurables del Inspector
* **`smasher_initial_speed`** *(float)*: Velocidad de movimiento inicial de las dianas (defecto: `150.0`).
* **`smasher_final_speed`** *(float)*: Velocidad máxima hacia el final de la partida (defecto: `350.0`).
* **`smasher_lives`** *(int)*: Errores permitidos antes de la derrota (defecto: `3`).

---

### 🦘 5. Minijuego TRAMPOLÍN (`MG_Trampolin`)
**Escena:** `res://src/minigames/mg_trampolin/mg_trampolin.tscn`  
**Estilo:** Salto vertical infinito sobre plataformas rebotadoras (estilo *Doodle Jump*).

#### Modos de Victoria (`trampolin_win_condition` / `win_condition`)
| Valor Numérico | Nombre en Inspector | Descripción | Parámetro Requerido |
| :---: | :--- | :--- | :--- |
| **`0`** | **Altura Alcanzada** | Ganar al alcanzar una coordenada de altura específica (Score en metros). | `trampolin_target_value` (ej. `500.0`). |
| **`1`** | **Plataforma Especial** | Ganar al alcanzar la plataforma dorada meta generada en la cima. | `trampolin_target_value` (índice o altura meta). |
| **`2`** | **Monedas Recolectadas** | Ganar al recoger una cantidad meta de monedas en el aire. | `trampolin_target_value` (ej. `15.0`). |

---

## 3. Tabla Rápida de Claves para Programación (`config` Dictionary)

Si necesitas lanzar un minijuego por código vía `GameManager.minigame_config = {...}` o sobreescribir opciones avanzadas, utiliza esta tabla de equivalencias directas:

| Minijuego | Clave de Diccionario | Tipo | Descripción |
| :--- | :--- | :---: | :--- |
| **Runner** | `"win_condition"` | `int` | `0` = Distancia, `1` = Objeto clave |
| | `"target_value"` | `float` | Metros meta si `win_condition = 0` |
| | `"target_item_id"` | `String` | ID del ítem meta si `win_condition = 1` |
| | `"target_distance_range"` | `Vector2` | Rango `(min, max)` en metros para spawnear el ítem meta |
| | `"run_speed"` | `float` | Velocidad de carrera |
| | `"coin_density"` | `float` | Densidad de monedas (`0.0` a `1.0`) |
| | `"item_pool"` | `Array[String]` | IDs de ítems secundarios (`["blue_potion", ...]`) |
| **Catcher** | `"game_mode"` | `String` | `"COUNT"` o `"TIME"` |
| | `"target_value"` | `float` | Puntos o Segundos |
| | `"lives"` | `int` | Vidas |
| | `"base_fall_speed"` | `float` | Velocidad de caída |
| | `"spawn_rate"` | `float` | Intervalo de spawn en segundos |
| **Excavation**| `"win_condition"` | `int` | `0` = Todas, `1` = Cantidad, `2` = Misión |
| | `"target_amount"` | `int` | Monedas necesarias |
| | `"rocks"` | `int` | Cantidad de rocas |
| | `"escala"` | `float` | Escala del grid |
| **Smasher** | `"game_mode"` | `String` | `"COUNT"` o `"TIME"` |
| | `"target_value"` | `float` | Dianas o Segundos |
| | `"initial_speed"` | `float` | Velocidad inicial |
| | `"final_speed"` | `float` | Velocidad final |
| **Trampolin**| `"win_condition"` | `int` | `0` = Altura, `1` = Especial, `2` = Monedas |
| | `"target_value"` | `float` | Meta numérica correspondiente |
| **Todos** | `"win_level_path"` | `String` | Ruta `.tscn` al ganar |
| | `"win_spawn_id"` | `String` | ID del `ArrivalSpawnPoint` de victoria |
| | `"lose_level_path"` | `String` | Ruta `.tscn` al perder |
| | `"lose_spawn_id"` | `String` | ID del `ArrivalSpawnPoint` de derrota |

---

## 4. Transferencia de Recompensas al Inventario

Cualquier minijuego que herede de `MinigameBase` acumula automáticamente sus recompensas durante la partida llamando a:
```gdscript
add_reward("item_id", cantidad)
```
* **En caso de Victoria:** Al presionar "Continuar" en la pantalla modal de fin de partida, `GameManager.complete_minigame(true, results)` transfiere el 100% de los ítems acumulados al singleton `Inventory` del jugador antes de regresar al mapa.
* **En caso de Derrota:** Los ítems recolectados en esa sesión no se transfieren al inventario global, evitando pérdidas de balance.
