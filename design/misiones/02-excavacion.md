# Minijuego 02: Excavación (Grid Espeleológico / Boulder Dash & Supaplex)

## 1. Core Loop

### Mecánica Base Invariable
El minijuego es un rompecabezas de acción táctica y física de gravedad en una grilla bidimensional de casillas ortogonales (estilo *Boulder Dash / Supaplex*).

* **Movimiento e Interacción en Grilla:** El jugador se desplaza en 4 direcciones cardinales (Arriba, Abajo, Izquierda, Derecha). Al avanzar hacia una casilla de tierra suave, la "cava" instantáneamente convirtiéndola en espacio vacío transitable.
* **Física de Gravedad y Deslizamiento de Rocas y Bombas:**
  * Las rocas y bombas suspendidas sobre casillas vacías caen verticalmente por gravedad.
  * Si reposan sobre una superficie redondeada (otra roca, bomba o muro curvo) y hay espacio lateral libre, se deslizan hacia el costado antes de caer.
  * Si una roca cae sobre el jugador, este es aplastado de inmediato (derrota).
  * El jugador puede empujar rocas y bombas horizontalmente si la casilla adyacente está libre.
* **Mecánica de Bombas y Demolición:**
  * *Bombas Ambientales:* Caen con la misma física; al impactar contra el suelo o cualquier obstáculo tras una caída, detonan instantáneamente en un radio de 3x3 casillas.
  * *Bombas Manuales:* Al mantener presionado `ESPACIO` / `ui_accept` durante ~0.35s sin moverse, el jugador planta una bomba estática con un temporizador de 4 segundos. Detona en 3x3 destruyendo tierra y rocas. Si el jugador no evacúa el radio letal a tiempo, muere en la explosión.
* **Condición de Salida:** Al cumplirse el objetivo (monedas, ítem especial o despeje), se desbloquea la trampilla de salida (`Exit Tile`), a la cual el jugador debe caminar para ganar.

### Referencia al Código y Escenas Actuales
* **Escena Principal:** `res://src/minigames/mg_excavation/mg_excavation_game.tscn`
* **Script del Controlador:** `res://src/minigames/mg_excavation/mg_excavation_game.gd` (Hereda de `MinigameBase`, clase `MG_ExcavationGame`)
* **Generador de Niveles:** `res://src/minigames/mg_excavation/level_generator.gd`
* **Tipos y Enums:** `res://src/minigames/mg_excavation/mg_excavation_types.gd` (`TileType`, `WinCondition`)
* **Configurador Inspector:** `res://src/minigames/tests/config_mg_excavation.gd`

---

## 2. Modificadores de Sesión

Los modificadores enriquecen el desafío espeleológico inyectando parámetros específicos desde `GameManager.minigame_config`:

### A. Tipos de Generación de Nivel (`map_generation_mode`)
1. **Procedural por Semilla (`procedural_seed`):** Genera cavernas orgánicas mediante autómatas celulares y densidad de rocas configurable (`excavation_rocks`).
2. **Layout Artesanal / Puzzle Curado (`handcrafted_layout`):** Carga un mapa predefinido con disposición exacta de rocas, pasadizos estrechos y bombas, ideal para misiones de trama principal donde se requiere un diseño de rompecabezas específico.

### B. Restricciones de Recursos
* **Reserva de Oxígeno (`oxygen_limit_seconds`):** Temporizador regresivo de aire respirable (ej. 90 segundos). Se reduce constantemente; cavar en vetas de ventilación (`air_vent`) restaura bocanadas de oxígeno.
* **Límite de Pasos / Movimientos (`step_limit`):** El jugador dispone de una cantidad máxima de casillas que puede transitar (ej. 150 pasos). Cada movimiento descuenta 1 punto; obliga a planificar rutas óptimas sin excavar de más.
* **Munición de Bombas Manuales (`initial_bombs`):** Bombas manuales con las que inicia el jugador (`player_bombs_ammo`).

### C. Peligros Ambientales Rotativos
* **Bolsas de Gas Metano (`methane_gas_tile`):** Casillas con gas inflamable volátil. Cavar a través de ellas reduce la visibilidad; si entra en contacto con la chispa de una explosión cercana de 3x3, desencadena una detonación en cadena masiva.
* **Enemigos Patrulleros de Caverna (`cave_crawler`):** Ciempiés blindados o escorpiones de roca que siguen las paredes del vacío excavado. No pueden eliminarse cuerpo a cuerpo; deben aplastarse haciéndoles caer una roca encima o detonando una bomba a su paso.
* **Oscuridad / Niebla de Espeleología (`fog_of_war`):** La visibilidad se restringe a un radio circular de 4 a 6 casillas alrededor del jugador, requiriendo memorización espacial y avance precavido.

---

## 3. Objetivos de Misión

Tres misiones concretas diseñadas para el pipeline de juego:

### Misión 1: "El Rescate de la Reliquia del Pozo" (Misión de Extracción Narrativa)
* **Contexto:** En el fondo de un pozo seco derrumbado en las afueras del pueblo, yace un cofre antiguo con el `ancient_map` necesario para descifrar las ruinas del castillo. El aire en la sima se está agotando con rapidez.
* **Condición de Victoria:** Localizar y extraer el objeto de misión (`target_item_id = "ancient_map"`) y alcanzar la trampilla de salida antes de que el oxígeno llegue a cero (`oxygen_limit_seconds = 75.0`).
* **Criterios de 3 Estrellas:**
  * ⭐ **1 Estrella (Superado):** Extraer la reliquia y cruzar la compuerta de salida.
  * ⭐⭐ **2 Estrellas (Maestría):** Escapar con al menos 25 segundos de oxígeno restante en el tanque.
  * ⭐⭐⭐ **3 Estrellas (Perfección):** Escapar con ≥ 35s de aire + extraer adicionalmente 1x `blue_gem` incrustada en roca profunda sin detonar bombas innecesarias.

### Misión 2: "Ruta de Eficiencia Minera" (Misión de Optimización y Pasos)
* **Contexto:** El soporte de vigas del filón norte está fracturado: cada paso excesivo aumenta la presión de la caverna. El Capataz Gorn exige extraer una cuota de mineral de hierro puro con el mínimo desgaste estructural.
* **Condición de Victoria:** Recolectar 12 unidades de `iron_ore` y llegar a la salida en menos de 140 pasos totales (`step_limit = 140`), utilizando como máximo 1 bomba manual.
* **Criterios de 3 Estrellas:**
  * ⭐ **1 Estrella (Superado):** Recolectar 12 minerales de hierro y salir vivo bajo el límite de 140 pasos.
  * ⭐⭐ **2 Estrellas (Maestría):** Completar la cuota y salida en menos de 105 pasos.
  * ⭐⭐⭐ **3 Estrellas (Perfección):** Salir en menos de 90 pasos SIN USAR NINGUNA BOMBA manual (pura resolución mediante empuje y física de piedras).

### Misión 3: "Operación Evacuación Profunda" (Misión de Rescate de Minero)
* **Contexto:** Un aprendiz de minero ha quedado incomunicado tras un desprendimiento de rocas y bombas inestables. Las paredes están a punto de ceder.
* **Condición de Victoria:** Cavar y volar de forma segura el tapón de rocas hasta llegar a la casilla del minero novato y abrirle un camino despejado hacia el elevador de salida antes de 90 segundos.
* **Criterios de 3 Estrellas:**
  * ⭐ **1 Estrella (Superado):** Despejar la ruta y permitir que el minero alcance el ascensor.
  * ⭐⭐ **2 Estrellas (Maestría):** Rescatar al minero sin que ninguna roca sufra una caída cerca de él (cero sustos/daño).
  * ⭐⭐⭐ **3 Estrellas (Perfección):** Completar el rescate en menos de 50 segundos utilizando un máximo de 2 bombas colocadas con precisión quirúrgica.

---

## 4. Gancho Narrativo e Integración en el Mundo

### Personaje Emisor y Locación
* **NPC:** Capataz Minero Gorn / Arqueóloga Lyra.
* **Ubicación:** Campamento de la Boca de la Mina (Acceso al Túnel Subterráneo del Overworld).
* **Activador:** Interacción con el montacargas o con Gorn mediante `DialogueManager` (`gorn_miner.dialogue`).

### Grado de Obligatoriedad
* **Instancia de Trama (Main Quest):** Obligatoria en el Acto 1. El túnel subterráneo es la única vía para infiltrarse tras los muros de la Ciudadela sin ser visto por los guardias del portón principal. La Misión 1 (*"El Rescate de la Reliquia del Pozo"*) es obligatoria para conseguir el `ancient_map` y la `rusty_key`.
* **Instancias Opcionales (Hub / Contratos Mineros):** El Capataz Gorn compra minerales extraídos y ofrece expediciones profundas para recolectar gemas y lingotes de forja.

### Desbloqueos y Recompensas
* **Recompensa Narrativa / Lore:** Otorga el ítem clave `ancient_map` y destraba los documentos de lore *"Planos de los Conductos Olvidados"* que revelan atajos secretos en el Overworld.
* **Recompensa Material:**
  * Primera vez: 1x `ancient_map`, 1x `rusty_key`, 4x `iron_ore`, 60x `gold_coins`.
  * Repetible: Minerales de hierro (`iron_ore`), gemas (`blue_gem`), 25x `gold_coins`.

---

## 5. Tabla de Progresión

| ID Misión | Título | Tipo | Desbloqueo | Modificadores Clave | Recompensa Primera Vez | Recompensa Repetible |
| :--- | :--- | :---: | :--- | :--- | :--- | :--- |
| `excav_01` | *La Reliquia del Pozo* | **Main Quest** | Acto 1 (Hablar con Gorn) | Mapa artesanal, Oxígeno 75s | `ancient_map` x1, `rusty_key` x1, 60 Oro | `iron_ore` x2, 20 Oro |
| `excav_02` | *Eficiencia Minera* | Contrato Hub | Tras completar `excav_01` | Límite 140 pasos, 1 sola bomba | `iron_ore` x6, `iron_key` x1, 80 Oro | `iron_ore` x3, 25 Oro |
| `excav_03` | *Evacuación Profunda* | Desafío Maestro | Acto 2 (Minería Avanzada) | Niebla de caverna, Minero escoltado | `blue_gem` x2, 180 Oro, Códice "Historia de las Ruinas" | `blue_gem` x1, 40 Oro |

---

## 6. Gaps Técnicos a Resolver

Comparando el diseño con el código actual (`mg_excavation_game.gd`, `level_generator.gd`, `mg_excavation_types.gd`):

1. **Ausencia de Soporte para Niveles Artesanales (Layouts Fijos):**
   * *Estado actual:* `_generate_level()` en `mg_excavation_game.gd` llama exclusivamente a `LevelGenerator.generate_level()` utilizando lógica procedural basada en autómatas celulares y ruido pseudoaleatorio.
   * *Requerimiento:* Crear una estructura de recurso o archivo JSON (`ExcavationMapData`) que permita pintar a mano mapas exactos para misiones de puzzle narrativas.
2. **Falta de Medidor de Oxígeno / Tiempo Regresivo con Puntos de Ventilación:**
   * *Estado actual:* No existe temporizador de asfixia ni pérdida de aire en `mg_excavation_game.gd`.
   * *Requerimiento:* Añadir la variable `oxygen_timer`, la UI de barra de aire en el HUD, y un tipo de celda `TileType.AIR_VENT` que recargue el medidor al pisarse.
3. **Falta de Contador de Pasos (`step_counter`):**
   * *Estado actual:* El jugador puede moverse indefinidamente por el grid sin límite de pasos.
   * *Requerimiento:* Contabilizar cada desplazamiento ortogonal efectivo (`player_grid_pos` cambiado) y gatillar derrota si se agotan los pasos permitidos.
4. **Niebla de Espeleología / Iluminación Local:**
   * *Estado actual:* La cámara muestra la totalidad del escenario o tiene zoom amplio sin oclusión visual (`$Camera2D`).
   * *Requerimiento:* Shader o máscara `PointLight2D` con canvas modulate negro para simular linterna de minero en misiones avanzadas.
5. **Evaluación de Estrellas en UI Modal:**
   * *Estado actual:* `_win_game()` llama directamente a `finish(true)` sin registrar métricas de pasos, bombas gastadas ni tiempo para calcular 1, 2 o 3 estrellas.
