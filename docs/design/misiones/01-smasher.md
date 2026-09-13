# Minijuego 01: Smasher (Aplasta-Plagas Top-Down)

## 1. Core Loop

### Mecánica Base Invariable
El minijuego es un desafío de reflejos, coordinación visomotora y selección rápida de objetivos en vista top-down (estilo *Whack-a-Mole*). 

* **Interacción Central:** El jugador observa un conjunto de agujeros o madrigueras en el terreno. De estos agujeros emergen entidades (insectos/plagas) durante un intervalo temporal definido (ventana de exposición).
* **Entrada del Jugador:** Mediante puntero del mouse (o tap táctil / cursor gamepad), el jugador hace click/presiona sobre la entidad antes de que esta se oculte nuevamente o escape.
* **Ciclo de Recompensa Inmediata:**
  1. Impacto exitoso: Se destruye la entidad con feedback auditivo y de partículas (`smashed`), sumando al contador de objetivos o combo.
  2. Escape de la entidad: La plaga se sumerge en la tierra sin recibir daño (`escaped`), lo que puede restar una vida o reducir la puntuación según el modo.
  3. Finalización: Al alcanzar la meta o agotarse el tiempo/vidas, el juego se congela y transfiere el control a `MinigameBase.finish()`.

### Referencia al Código y Escenas Actuales
* **Escena Principal:** `res://src/minigames/mg_smasher/mg_smasher_game.tscn`
* **Script del Controlador:** `res://src/minigames/mg_smasher/mg_smasher_game.gd` (Hereda de `MinigameBase`)
* **Entidad Objetivo:** `res://src/minigames/mg_smasher/insect.tscn` y `insect.gd`
* **Configurador Inspector:** `res://src/minigames/mg_smasher/config_mg_smasher.gd`

---

## 2. Modificadores de Sesión

Los modificadores alteran la dinámica sin tocar el core loop y se inyectan dinámicamente mediante el diccionario `GameManager.minigame_config`:

### A. Catálogo de Variantes de Bichos (`insect_type`)
1. **Oruga de Plaga Básica (`caterpillar_normal`):**
   * Salud: 1 golpe.
   * Tiempo en superficie: 1.2s - 0.8s.
   * Comportamiento: Asoma la cabeza, permanece quieta y vuelve a descender.
2. **Escarabajo Blindado (`beetle_armored`):**
   * Salud: 2 golpes rápidos obligatorios.
   * Tiempo en superficie: 1.5s.
   * Feedback: El primer golpe agrieta su caparazón con sonido metálico y reduce su tamaño; el segundo lo destruye.
3. **Oruga Espinosa / Bicho Trampa (`caterpillar_trap`):**
   * Regla de Penalización: **NO DEBE TOCARSE**.
   * Visual: Color rojo/púrpura brillante con púas vibrantes y aura de peligro.
   * Penalización: Al recibir un click, inflige daño directo (-1 vida) o aturde el cursor durante 0.5s.
4. **Bicho Escurridizo / Saltador (`bug_runner`):**
   * Comportamiento: Emerge en el Agujero A, se queda 0.3s y da un salto rápido al Agujero B adyacente antes de ocultarse. Requiere interceptar la trayectoria o anticipar el segundo agujero.
5. **Señuelo Silvestre / Flor Trampa (`flower_decoy`):**
   * Visual: Flor o mariposa inofensiva que asoma rápidamente. Golpearla no quita vidas pero anula la racha de combo y falla los criterios de precisión.

### B. Layouts de la Grilla de Agujeros (`layout_preset`)
* **`grid_3x3` (Huerto Regular):** 9 agujeros dispuestos simétricamente en 3 filas y 3 columnas. Ideal para lectura ordenada de patrones.
* **`perimeter_ring` (Círculo de Protección):** 8 a 12 agujeros rodeando un brote de planta sagrada central.
* **`wild_scattered` (Madrigueras del Bosque):** 10 a 16 agujeros distribuidos asimétricamente entre rocas y raíces, simulando un claro silvestre.

### C. Parámetros Numéricos Inyectables
* `smasher_target_value` *(float)*: Cantidad de capturas requeridas o tiempo de aguante.
* `smasher_initial_speed` y `smasher_final_speed` *(float)*: Control de la velocidad de emergencia y animación.
* `smasher_lives` *(int)*: Vidas permitidas antes de la derrota.
* `miss_click_penalty` *(bool)*: Si hacer click en el suelo vacío sin golpear nada cuenta como fallo de precisión.

---

## 3. Objetivos de Misión

A continuación se detallan 3 variantes concretas listas para producción:

### Misión 1: "La Plaga del Invernadero de Barnaby" (Misión de Precisión)
* **Contexto:** Las orugas devoradoras están masticando los brotes medicinales de Barnaby. Es un trabajo meticuloso: no se pueden romper las macetas con golpes erráticos.
* **Condición de Victoria:** Aplastar 20 orugas normales (`target_value = 20`) sin perder todas las vidas (`lives = 3`).
* **Criterios de 3 Estrellas:**
  * ⭐ **1 Estrella (Superado):** Eliminar las 20 orugas requeridas.
  * ⭐⭐ **2 Estrellas (Maestría):** Finalizar con al menos 2 vidas restantes y una precisión de clicks ≥ 80%.
  * ⭐⭐⭐ **3 Estrellas (Perfección):** 100% de precisión (cero clicks en vacío) y completar la misión en menos de 25 segundos.

### Misión 2: "Cosecha Segura entre Espinas" (Misión de Control de Impulso)
* **Contexto:** Una cepa venenosa de orugas espinosas ha brotado entre las plagas habituales. El jugador debe mantener la calma y filtrar rápidamente sus ataques.
* **Condición de Victoria:** Eliminar 25 plagas devoradoras en un plazo de 45 segundos, tolerando un máximo de 1 toque accidental a un bicho trampa.
* **Criterios de 3 Estrellas:**
  * ⭐ **1 Estrella (Superado):** Eliminar 25 plagas antes de que expire el tiempo.
  * ⭐⭐ **2 Estrellas (Maestría):** Cero golpes a orugas espinosas (cero toques de trampa).
  * ⭐⭐⭐ **3 Estrellas (Perfección):** Cero toques a trampas + eliminar al menos 32 plagas (ritmo frenético) sin perder vidas.

### Misión 3: "Caza de la Oruga Reina Mimética" (Misión de Observación e Identificación)
* **Contexto:** Las plagas están coordinadas por Orugas Reina que se mimetizan entre falsos insectos y señuelos. Requiere agudeza visual instantánea.
* **Condición de Victoria:** Identificar y aplastar a 6 Orugas Reina (distinguibles por sus antenas doradas brillantes) antes de cometer 3 fallos sobre señuelos inocentes.
* **Criterios de 3 Estrellas:**
  * ⭐ **1 Estrella (Superado):** Aplastar a las 6 Orugas Reina.
  * ⭐⭐ **2 Estrellas (Maestría):** No golpear ningún señuelo inocente (0 errores de identificación).
  * ⭐⭐⭐ **3 Estrellas (Perfección):** Cero errores + aplastar a cada Reina en menos de 0.7 segundos tras su emergencia.

---

## 4. Gancho Narrativo e Integración en el Mundo

### Personaje Emisor y Locación
* **NPC:** Barnaby (Jardinero y Maestro Boticario del Poblado Inicial).
* **Ubicación:** Invernadero Viejo del Valle Sur (`res://src/overworld/levels/`).
* **Activador:** Diálogo interactivo vía `DialogueManager` (`barnaby.dialogue`).

### Grado de Obligatoriedad
* **Instancia de Trama (Main Quest):** Obligatoria en el Acto 1. Para que Barnaby entregue el `antidote` que cura la toxina del portal hacia el Bosque Prohibido, el jugador debe superar con éxito la Misión 1 (*"La Plaga del Invernadero de Barnaby"*).
* **Instancias Opcionales (Hub / Tablón de Misiones):** Disponibles a partir de ese momento en el tablón comunal del pueblo como contratos remunerados para farmear ingredientes de botica.

### Desbloqueos y Recompensas
* **Recompensa Narrativa / Lore:** Desbloquea la entrada de códice *"Bestiario: Entomología del Valle"*, la cual explica debilidades elementales de los monstruos insectoides que habitan en los niveles abiertos.
* **Recompensa Material:**
  * Primera vez: 1x `antidote`, 3x `green_herb`, 40x `gold_coins`.
  * Repetible: 1x `green_herb`, 10x `gold_coins`.

---

## 5. Tabla de Progresión

| ID Misión | Título | Tipo | Desbloqueo | Modificadores Clave | Recompensa Primera Vez | Recompensa Repetible |
| :--- | :--- | :---: | :--- | :--- | :--- | :--- |
| `smash_01` | *La Plaga del Invernadero* | **Main Quest** | Acto 1 (Hablar con Barnaby) | Grilla 3x3, Orugas normales | `antidote` x1, `green_herb` x3, 40 Oro, Códice Lore | `green_herb` x1, 10 Oro |
| `smash_02` | *Cosecha entre Espinas* | Contrato Hub | Tras completar `smash_01` | Grilla irregular, Bichos trampa | `blue_potion` x1, 75 Oro | `green_herb` x1, 15 Oro |
| `smash_03` | *Caza de la Reina* | Desafío Maestro | Acto 2 (Reputación Boticaria) | Señuelos miméticos, Bichos saltadores | `blue_gem` x1, 150 Oro, Título "Cazador Preciso" | 30 Oro |

---

## 6. Gaps Técnicos a Resolver

Al contrastar este diseño de producción con la base de código actual (`mg_smasher_game.gd` e `insect.gd`), se identifican los siguientes puntos técnicos a corregir:

1. **Discrepancia de Mecánica Espacial (Curva vs. Agujeros Whack-A-Mole):**
   * *Estado actual:* `insect.gd` se mueve a lo largo de una curva sinusoidal (`Curve2D`) desde un agujero en el borde de la pantalla hacia otro borde opuesto (`mg_smasher_game.gd: setup_game()`).
   * *Requerimiento:* Las misiones tipo Whack-A-Mole requieren que los bichos emerjan verticalmente desde una posición estática (agujero de grilla) y permanezcan visibles un tiempo antes de sumergirse. Debe implementarse un modo o nodo de agujero fijo (`SmasherHole`).
2. **Falta de Variantes de Insectos (Polimorfismo / Estados):**
   * *Estado actual:* Solo existe una única clase `insect.gd` de 1 solo toque que desaparece de inmediato.
   * *Requerimiento:* Se necesita dar soporte a resistencia de impactos (`hits_required: int`), penalización por toque accidental (`is_trap: bool`) y comportamiento evasivo/saltador (`is_runner: bool`).
3. **Detección de Clicks Fallidos (Métrica de Precisión):**
   * *Estado actual:* Hacer click sobre el fondo o área vacía no se captura ni penaliza en el juego.
   * *Requerimiento:* El fondo de `mg_smasher_game.tscn` debe capturar `_gui_input` o `unhandled_input` para contabilizar `misses` y evaluar la precisión requerida para las 3 estrellas.
4. **Evaluación de Rendimiento de 3 Estrellas en UI:**
   * *Estado actual:* Al ganar, se llama inmediatamente a `finish(true)` mostrando un texto genérico de victoria.
   * *Requerimiento:* Integrar el cálculo de estrellas y su presentación visual en la pantalla modal de resultados de `MinigameBase`.
