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
* **`runner_speed`** *(float)*: Velocidad base de avance de la pista en píxeles/segundo (defecto: `380.0`).
* **`runner_speed_increase_interval`** *(float)*: Distancia en metros para aumentar gradualmente la velocidad de carrera (defecto: `200.0`).
* **`runner_speed_increase_amount`** *(float)*: Cantidad de velocidad extra añadida en cada intervalo (defecto: `25.0`).
* **`runner_ammo_initial_distance`** *(float)*: Distancia inicial en metros para que aparezca la primera recarga de munición (+1 bala) (defecto: `250.0`).
* **`runner_ammo_distance_multiplier`** *(float)*: Multiplicador progresivo que aleja cada nueva aparición de munición respecto a la anterior (defecto: `1.5`).
* **`runner_coin_density`** *(float)*: Probabilidad (de `0.0` a `1.0`) de que aparezcan patrones de monedas (defecto: `0.55`).
* **`runner_max_coins`** *(int)*: Cantidad máxima de monedas que pueden aparecer en la partida (`-1` = sin límite).
* **`runner_item_pool`** *(Array[String])*: Lista de IDs de ítems secundarios que pueden aparecer flotando en la pista para sumarse al inventario (ej. `["blue_potion", "red_potion", "green_herb"]`).

#### Patrones de Monedas y Spacing Inteligente
* **Líneas de 1, 2, 3 o 4 monedas:** Generadas a ras de carrera horizontal ($Y = 765$).
* **Patrón en V:** Valle de monedas altas en los extremos y bajas en el centro.
* **Patrón en V Invertida:** Arco parabólico de 5 monedas diseñado para guiar y premiar el salto sobre obstáculos terrestres.
* **Anti-Solapamiento Inteligente:** Las monedas y pickups no se generan encima de obstáculos ni en zonas colindantes para garantizar legibilidad de salto.

#### Controles del Jugador
* **Saltar:** `ESPACIO`, `FLECHA ARRIBA`, `W` o Botón Inferior de Gamepad (Botón A / Cruz) (impulso parabólico y cola de salto anticipada).
* **Agacharse / Deslizarse:** `FLECHA ABAJO`, `S` o Botón Derecho de Gamepad (Botón B / Círculo) (reduce colisionador de 115 px a 52 px para pasar bajo obstáculos aéreos).
* **Caída Rápida (*Fast-Fall*):** Presionar abajo mientras estás en el aire acelera la gravedad para aterrizar de inmediato.
* **Disparar:** Tecla `Z` o Botón Izquierdo de Gamepad (Botón X / Cuadrado) (consume 1 bala para destruir cajas y enemigos frontales).

---

### ⛏️ 2. Minijuego EXCAVACIÓN (`MG_Excavation`)
**Escena:** `res://src/minigames/mg_excavation/mg_excavation_game.tscn`  
**Estilo:** Grid 2D de excavación procedural con gravedad de rocas y bombas (estilo *Boulder Dash / Supaplex*).

#### Modos de Victoria (`excavation_win_condition` / `win_condition`)
| Valor Numérico | Nombre en Inspector | Descripción | Parámetro Requerido |
| :---: | :--- | :--- | :--- |
| **`0`** | **Todas las Monedas** | Recolectar el 100% de las monedas generadas en todo el mapa de tierra. | Ninguno (automático). |
| **`1`** | **Cantidad Específica** | Alcanzar un número determinado de monedas para abrir la salida. | `excavation_target_amount` (ej. `10`). |
| **`2`** | **Ítem de Misión** | Desenterrar y recoger un ítem de misión especial escondido en el nivel. | Objeto de misión en mapa. |

#### Parámetros Configurables del Inspector
* **`excavation_rocks`** *(int)*: Densidad de rocas y bombas ambientales que caen por gravedad (defecto: `10`).
* **`excavation_scale`** *(float)*: Multiplicador de escala visual del mapa (defecto: `1.5`).
* **`excavation_deliver_items`** *(bool)*: Si está activo, reemplaza aleatoriamente algunos bloques de tierra por ítems recolectables visibles del `item_pool` y pickups de bombas manuales.
* **`excavation_initial_bombs`** *(int)*: Bombas manuales con las que inicia el jugador (defecto: `1`).
* **`excavation_item_pool`** *(Array[String])*: Lista de ítems de inventario que pueden aparecer en el terreno visible.

#### Mecánica de Bombas y Física
1. **Bombas Ambientales:**
   * Tienen la misma física de gravedad y deslizamiento lateral que las piedras.
   * Se pueden empujar horizontalmente si el espacio contiguo está libre.
   * **Impacto:** Al caer y golpear cualquier superficie, obstáculo o al jugador, detonan en una explosión de 3x3 casillas.
2. **Bombas Manuales (Colocadas por el Jugador):**
   * El jugador recoge pickups de bomba en el mapa para ganar munición.
   * Al mantener presionado `ESPACIO` / `ui_accept` sin moverse (~0.35s), se coloca una bomba estática en la casilla del jugador.
   * Cuenta regresiva de 4 segundos con pulso visual.
   * **Lethal Radius:** Detona en un área de 3x3 destruyendo rocas y tierra (la salida y muros exteriores son indestructibles). Si el jugador está dentro del radio de 3x3 al explotar, muere aplastado/destruido.

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
* **`catcher_item_pool`** *(Array[String])*: Lista de ítems de inventario que pueden otorgarse como recompensas directas al atrapar objetos especiales.
* **`catcher_critical_item_ids`** *(Array[String])*: IDs de ítems que se consideran críticos.

#### Mecánica de Suelo y Expiración
* Los objetos que caen al suelo no desaparecen instantáneamente: permanecen en el piso durante **3.0 segundos**.
* Durante el último segundo parpadean alertando su desaparición inminente.
* El jugador puede caminar sobre el suelo para recoger los objetos rezagados.
* **Pérdida de Vida por Negligencia:** Si un ítem crítico expira en el suelo sin ser recogido, el jugador pierde 1 vida inmediatamente.

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
* **Visuales:** Utiliza el sprite oficial de araña (`spider_enemy.png`) orientado hacia adelante en la dirección de desplazamiento sinusoidal de la trayectoria.

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

#### Parámetros Configurables del Inspector
* **`trampolin_item_chance`** *(float)*: Probabilidad (de `0.0` a `1.0`) de que una plataforma o trampolín contenga un ítem de inventario reposando sobre su superficie (defecto: `0.25`).
* **`trampolin_item_pool`** *(Array[String])*: Lista de ítems que pueden reposar sobre las plataformas.

#### Mecánica de Ítems en Plataformas
* A diferencia de las monedas (que flotan en el aire en trayectorias de salto), los ítems descansan directamente sobre la superficie del trampolín o plataforma y se recogen por contacto físico directo al aterrizar o rebotar sobre ellos.

---

## 3. Tabla Rápida de Claves para Programación (`config` Dictionary)

Si necesitas lanzar un minijuego por código vía `GameManager.minigame_config = {...}` o sobreescribir opciones avanzadas, utiliza esta tabla de equivalencias directas:

| Minijuego | Clave de Diccionario | Tipo | Descripción |
| :--- | :--- | :---: | :--- |
| **Runner** | `"win_condition"` | `int` | `0` = Distancia, `1` = Objeto clave |
| | `"target_value"` | `float` | Metros meta si `win_condition = 0` |
| | `"target_item_id"` | `String` | ID del ítem meta si `win_condition = 1` |
| | `"target_distance_range"` | `Vector2` | Rango `(min, max)` en metros para spawnear el ítem meta |
| | `"run_speed"` | `float` | Velocidad de carrera base |
| | `"speed_increase_interval"`| `float`| Cada cuántos metros acelera el runner |
| | `"speed_increase_amount"`  | `float`| Incremento de velocidad por intervalo |
| | `"ammo_spawn_initial_distance"`| `float`| Distancia del primer pickup de munición |
| | `"ammo_spawn_distance_multiplier"`| `float`| Multiplicador de separación para munición |
| | `"coin_density"` | `float` | Densidad de monedas (`0.0` a `1.0`) |
| | `"item_pool"` | `Array[String]` | IDs de ítems secundarios (`["blue_potion", ...]`) |
| **Catcher** | `"game_mode"` | `String` | `"COUNT"` o `"TIME"` |
| | `"target_value"` | `float` | Puntos o Segundos |
| | `"lives"` | `int` | Vidas |
| | `"base_fall_speed"` | `float` | Velocidad de caída |
| | `"spawn_rate"` | `float` | Intervalo de spawn en segundos |
| | `"item_pool"` | `Array[String]` | Pool de ítems otorgables |
| | `"critical_item_ids"` | `Array[String]` | IDs de ítems que quitan vida al expirar en suelo |
| **Excavation**| `"win_condition"` | `int` | `0` = Todas, `1` = Cantidad, `2` = Misión |
| | `"target_amount"` | `int` | Monedas necesarias |
| | `"rocks"` | `int` | Cantidad de rocas |
| | `"escala"` | `float` | Escala del grid |
| | `"deliver_items"` | `bool` | Poblar mapa con ítems visibles y bombas manuales |
| | `"initial_bombs"` | `int` | Bombas con las que inicia el jugador |
| | `"item_pool"` | `Array[String]` | Pool de ítems para poblar la tierra |
| **Smasher** | `"game_mode"` | `String` | `"COUNT"` o `"TIME"` |
| | `"target_value"` | `float` | Dianas o Segundos |
| | `"initial_speed"` | `float` | Velocidad inicial |
| | `"final_speed"` | `float` | Velocidad final |
| **Trampolin**| `"win_condition"` | `int` | `0` = Altura, `1` = Especial, `2` = Monedas |
| | `"target_value"` | `float` | Meta numérica correspondiente |
| | `"item_spawn_chance"` | `float` | Probabilidad de ítem en plataforma (`0.0` a `1.0`) |
| | `"item_pool"` | `Array[String]` | Pool de ítems en plataformas |
| **Todos** | `"win_level_path"` | `String` | Ruta `.tscn` al ganar |
| | `"win_spawn_id"` | `String` | ID del `ArrivalSpawnPoint` de victoria |
| | `"lose_level_path"` | `String` | Ruta `.tscn` al perder |
| | `"lose_spawn_id"` | `String` | ID del `ArrivalSpawnPoint` de derrota |

---

## 4. Transferencia de Recompensas y Feedback Visual de Loot

Cualquier minijuego que herede de `MinigameBase` acumula automáticamente sus recompensas durante la partida llamando a:
```gdscript
add_reward("item_id", cantidad)
```
* **En caso de Victoria:** Al volver al mapa principal, `GameManager` transfiere los ítems acumulados al `Inventory` y activa el **`LootFeedbackManager`**, haciendo que los iconos de los objetos obtenidos vuelen hacia la zona del inventario del HUD en cascada descendente.
* **En caso de Derrota:** Los ítems recolectados en esa sesión no se transfieren al inventario global, evitando pérdidas de balance.

