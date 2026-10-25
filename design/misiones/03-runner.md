# Minijuego 03: Runner (Carrera, Maniobras y Disparo Frontal)

## 1. Core Loop

### Mecánica Base Invariable
El minijuego es un side-scroller de desplazamiento lateral continuo a alta velocidad que combina reflejos acrobáticos y combate a distancia (estilo *Endless / Dino Runner* con disparos).

* **Avance Continuo y Scroll:** El escenario y los objetos se desplazan de derecha a izquierda contra el jugador a una velocidad base ajustable (`run_speed`), la cual acelera progresivamente cada cierto intervalo de metros recorridos (`speed_increase_interval`).
* **Habilidades Motrices del Jugador:**
  * **Salto Parabólico (`W`, `ESPACIO`, `FLECHA ARRIBA`):** Impulso vertical con cola de salto para superar fosas, obstáculos terrestres y alcanzar monedas flotantes.
  * **Agacharse / Deslizarse (`S`, `FLECHA ABAJO`):** Reduce a la mitad el colisionador del personaje (de 115 px a 52 px) para deslizarse por debajo de vigas bajas, trampas suspendidas y proyectiles aéreos.
  * **Caída Rápida (*Fast-Fall*):** Pulsar abajo en el aire acelera la gravedad hacia el suelo para aterrizar inmediatamente y esquivar obstáculos consecutivos.
  * **Disparo Frontal (`Z` o Botón de Acción):** Consume 1 unidad de munición para lanzar un proyectil horizontal a gran velocidad que destruye cajas, barricadas y enemigos en el carril de carrera.
* **Recursos en Carrera:** Municiones escasas (`runner_ammo`) y patrones estructurados de monedas (`runner_coins`) que premian la sincronización de saltos parabólicos (líneas, patrón en V y arcos en V invertida).

### Referencia al Código y Escenas Actuales
* **Escena Principal:** `res://src/minigames/mg_runner/mg_runner_level.tscn`
* **Script del Controlador:** `res://src/minigames/mg_runner/mg_runner_level.gd` (Hereda de `MinigameBase`)
* **Personaje del Runner:** `res://src/minigames/mg_runner/mg_runner_player.gd` y `mg_runner_player.tscn`
* **Proyectiles y Combate:** `res://src/minigames/mg_runner/mg_runner_bullet.gd` y `mg_runner_bullet.tscn`
* **Entidades de Obstáculo y Enemigo:** `res://src/minigames/mg_runner/mg_runner_obstacle.gd` y `mg_runner_enemy.gd`
* **Configurador Inspector:** `res://src/minigames/tests/config_mg_runner.gd`

---

## 2. Modificadores de Sesión

Parámetros y mecánicas inyectadas mediante `GameManager.minigame_config` para enriquecer la rejugabilidad:

### A. Variantes de Obstáculos y Enemigos de Reacción Específica
1. **Barricada de Asedio Reforzada (`barricade_heavy`):**
   * Regla: Demasiado alta para saltar y no se puede esquivar rodando.
   * Solución Obligatoria: Debe destruirse con 1 disparo de bala antes de impactar contra ella.
2. **Escudero Blindado (`enemy_shield`):**
   * Regla: Porta un escudo que repele los disparos frontales haciéndolos rebotar.
   * Solución Obligatoria: El jugador debe deslizarse por debajo (`slide`) o saltar con precisión justo por encima de su cabeza.
3. **Dron Vigilante / Murciélago Aéreo (`flying_watcher`):**
   * Posición: Altura media-alta.
   * Opciones: Agacharse para pasar limpio por debajo o apuntar un salto disparado.

### B. Rutas Bifurcadas y Altura Variable (`branching_tracks`)
* **Vía Baja (Camino del Fango):** Continúa sobre el suelo principal ($Y = 820$). Mayor densidad de barricadas pesadas y lodo que frena el avance si no se salta a tiempo.
* **Vía Alta (Ruta de las Azoteas / Puentes Colgantes):** Plataformas flotantes que se alcanzan con un salto enérgico. Libre de enemigos acorazados y rica en monedas y botines raros, pero con caídas al vacío si se pierde el ritmo.

### C. Modificadores Físicos y Mejoras
* `double_jump_enabled` *(bool)*: Otorga un segundo impulso de salto en el aire, ideal para misiones aéreas o recuperación de emergencia.
* `run_speed_multiplier` *(float)*: Velocidad base acelerada para desafíos de reflejos extremos.
* `ammo_scarcity` *(float)*: Factor de distancia que hace que las recargas de balas aparezcan mucho más lejos.

---

## 3. Objetivos de Misión

Tres misiones concretas diseñadas para el flujo de la campaña y contratos de gremio:

### Misión 1: "Huida del Puesto Fronterizo" (Misión de Checkpoints Narrativos)
* **Contexto:** El destacamento enemigo ha descubierto al protagonista. Debe emprender una carrera desesperada de 1200 metros por la calzada fortificada pasando por 3 puestos de avanzada en llamas antes de que cierren las rejas de la fortaleza.
* **Condición de Victoria:** Recorrer 1200 metros (`target_value = 1200.0`) y cruzar el portal de escape con vida.
* **Criterios de 3 Estrellas:**
  * ⭐ **1 Estrella (Superado):** Alcanzar la meta de 1200 metros.
  * ⭐⭐ **2 Estrellas (Maestría):** Llegar sin agotar más de 3 balas y sin recibir más de 1 impacto.
  * ⭐⭐⭐ **3 Estrellas (Perfección):** 100% de salud (cero golpes sufridos en todo el trayecto) y recolectar al menos 35 monedas de la calzada.

### Misión 2: "Incursión de Demolición de Barricadas" (Misión de Puntería y Munición)
* **Contexto:** Los asaltantes han levantado empalizadas de madera para cortar el suministro de alimentos al pueblo. El jugador debe liderar una avanzada de demolición rápida.
* **Condición de Victoria:** Destruir al menos 15 barricadas de asedio con disparos frontales certeros a lo largo de 1000 metros de carrera.
* **Criterios de 3 Estrellas:**
  * ⭐ **1 Estrella (Superado):** Destruir 15 barricadas y alcanzar el final del tramo.
  * ⭐⭐ **2 Estrellas (Maestría):** 100% de puntería de proyectiles (ninguna bala disparada al vacío; cada bala destruye un objetivo).
  * ⭐⭐⭐ **3 Estrellas (Perfección):** Destruir 20 barricadas + recoger el arcón de suministros secreto en la ruta alta de plataformas.

### Misión 3: "Despacho Urgente: El Correo Real" (Misión de Escolta e Integridad)
* **Contexto:** El Mensajero Real ha sido herido; el jugador debe transportar el cilindro lacrado con el tratado de paz hasta la vanguardia aliada. La cera del sello es extremadamente frágil.
* **Condición de Victoria:** Recorrer 1500 metros sin sufrir colisiones directas que rompan el sello del mensaje (tolerancia máxima de 1 roce leve).
* **Criterios de 3 Estrellas:**
  * ⭐ **1 Estrella (Superado):** Llegar a los 1500m con el mensaje legible.
  * ⭐⭐ **2 Estrellas (Maestría):** Transitar por la ruta alta elevada durante al menos 500 metros continuos.
  * ⭐⭐⭐ **3 Estrellas (Perfección):** Cero impactos absolutos (sello intacto al 100%) y finalizar en tiempo récord manteniendo la máxima aceleración sin caídas.

---

## 4. Gancho Narrativo e Integración en el Mundo

### Personaje Emisor y Locación
* **NPC:** Mensajero Real Elian / Capitán Valerius.
* **Ubicación:** Puesto de Guardia del Puente Este (Overworld).
* **Activador:** Diálogo de emergencia tras sonar la trompeta de asedio en el mapa (`guard_post.dialogue`).

### Grado de Obligatoriedad
* **Instancia de Trama (Main Quest):** Obligatoria en el clímax del Acto 2. El puente fronterizo se derrumba y la única vía para alertar al Castillo Central es cruzar la calzada hostil a toda velocidad en la Misión 1 (*"Huida del Puesto Fronterizo"*).
* **Instancias Opcionales (Hub / Mensajería Exprés):** En la Posada del Hub, el Gremio de Mensajeros ofrece contratas de transporte rápido de mercancías con bonificaciones por tiempo y recolección de monedas.

### Desbloqueos y Recompensas
* **Recompensa Narrativa / Lore:** Permite cruzar legalmente el puente levadizo del Overworld hacia la provincia central y desbloquea el fragmento de lore *"Crónicas del Asedio de la Frontera"*.
* **Recompensa Material:**
  * Primera vez: 1x `leather_cap` (casco de agilidad), 1x `wooden_sword` reforzada, 80x `gold_coins`.
  * Repetible: `bread` x2 (ración de viaje), 30x `gold_coins`.

---

## 5. Tabla de Progresión

| ID Misión | Título | Tipo | Desbloqueo | Modificadores Clave | Recompensa Primera Vez | Recompensa Repetible |
| :--- | :--- | :---: | :--- | :--- | :--- | :--- |
| `run_01` | *Huida Fronteriza* | **Main Quest** | Acto 2 (Asedio del Puente) | 1200m, barricadas y drones | `leather_cap` x1, Salvoconducto, 80 Oro | `bread` x2, 25 Oro |
| `run_02` | *Demolición de Asedio* | Contrato Hub | Tras completar `run_01` | Munición escasa, 15 barricadas | `red_potion` x2, 100 Oro | `iron_ore` x2, 30 Oro |
| `run_03` | *El Correo Real* | Desafío Maestro | Acto 3 (Gremio de Mensajería) | Integridad frágil, Rutas altas | `blue_gem` x2, Botas Aladas (Lore), 200 Oro | 50 Oro |

---

## 6. Gaps Técnicos a Resolver

Al analizar el código fuente de `mg_runner_level.gd`, `mg_runner_player.gd` y `mg_runner_obstacle.gd`:

1. **Escenario Monocarril (Falta de Rutas Bifurcadas y Plataformas Altas):**
   * *Estado actual:* Todo el nivel se genera sobre una única coordenada horizontal de suelo fijo (`GROUND_Y = 820.0`).
   * *Requerimiento:* Crear generadores de plataformas elevadas intermedias para dar soporte a saltos verticales y rutas alternativas (alta/baja).
2. **Falta de Enemigos con Regla de Interacción Estricta (Escudos vs. Barricadas):**
   * *Estado actual:* `mg_runner_bullet.gd` destruye cualquier nodo que colisione con él si tiene método `hit()` o está en el grupo.
   * *Requerimiento:* Definir enemigos inmunes al proyectil frontal (`has_shield`) que obliguen al jugador a deslizarse por debajo (`slide`), y barricadas de madera que maten al jugador si intenta saltarlas sin disparar.
3. **Mecánica de Doble Salto (`double_jump`):**
   * *Estado actual:* `mg_runner_player.gd` solo admite un único impulso de salto por contacto con el suelo.
   * *Requerimiento:* Añadir flag `can_double_jump` y variable `jumps_remaining: int` en el controlador del jugador.
4. **Fondo Dinámico y Señalización de Checkpoints:**
   * *Estado actual:* El parallax del fondo y la línea de suelo son constantes en todo el recorrido.
   * *Requerimiento:* Incluir marcadores visuales en el fondo al alcanzar hitos (ej. 400m, 800m, 1200m) para evidenciar progreso de historia.
5. **Evaluación de Estrellas en UI Modal:**
   * *Estado actual:* La victoria por distancia llama inmediatamente a `finish(true)` sin evaluar salud residual ni precisión de tiro.
