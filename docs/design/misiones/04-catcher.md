# Minijuego 04: Catcher (Recolección e Intercepción Alquímica)

## 1. Core Loop

### Mecánica Base Invariable
El minijuego es un desafío de coordinación lateral, posicionamiento táctico y priorización de objetos descendentes bajo gravedad (estilo *Object Catcher / Fruit Catcher*).

* **Movimiento Horizontal del Receptor:** El jugador controla un recolector (recipiente, canasta o personaje con red) a lo largo del eje X en la zona inferior de la pantalla (`catcher_player.gd`).
* **Lluvia de Objetos Descendentes:** Desde la parte superior emergen objetos a intervalos configurables (`spawn_rate`). Los objetos descienden a velocidad constante o acelerada (`base_fall_speed`).
* **Reglas de Contacto Directo:**
  * **Ítems Favorables:** Al hacer contacto con la canasta, otorgan puntos, suman al progreso de la misión o se almacenan en el buffer de recompensa (`add_reward()`).
  * **Objetos Hostiles / Bombas:** Si una bomba o espora letal entra en contacto con el recolector, explota infligiendo daño directo (-1 vida en `catcher_lives`) y genera una sacudida de pantalla (*screen shake*).
* **Mecánica de Suelo y Expiración:**
  * Los objetos que no son interceptados en el aire impactan contra el suelo y permanecen allí durante **3.0 segundos**.
  * Durante el último segundo parpadean alertando su evaporación. El jugador puede barrer el suelo para rescatarlos.
  * Si un ítem crítico (`critical_item_ids`) se evapora en el suelo sin ser recogido, el jugador pierde 1 vida por negligencia.

### Referencia al Código y Escenas Actuales
* **Escena Principal:** `res://src/minigames/mg_catcher/mg_catcher_game.tscn`
* **Script del Controlador:** `res://src/minigames/mg_catcher/mg_catcher_game.gd` (Hereda de `MinigameBase`)
* **Personaje del Jugador:** `res://src/minigames/mg_catcher/catcher_player.gd` y `catcher_player.tscn`
* **Entidades Descendentes:** `res://src/minigames/mg_catcher/falling_item_base.gd`, `falling_item_point.tscn` y `falling_item_bomb.tscn`
* **Configurador Inspector:** `res://src/minigames/mg_catcher/config_mg_catcher.gd`

---

## 2. Modificadores de Sesión

Parámetros dinámicos inyectables mediante `GameManager.minigame_config` para enriquecer cada contrato:

### A. Física Ambiental y Fuerzas Externas
* **Ráfagas de Viento Lateral (`wind_force_strength`):** Viento oscilante que empuja los objetos hacia la izquierda o derecha mientras caen, creando trayectorias parabólicas o erráticas que impiden predecir su caída de forma lineal.
* **Gravedad Diferencial por Densidad (`variable_gravity`):** Cristales y metales pesados caen a gran velocidad (350 px/s), mientras que esporas botánicas y plumas flotan suavemente (120 px/s), generando cruces y solapamientos en pantalla.

### B. Sistema de Contenedor Dual / Clasificación (`dual_basket_mode`)
* El jugador dispone de dos receptores conmutables (mediante `ESPACIO`, `TAB` o botones laterales):
  * **Canasta Acolchada de Botica:** Para recibir hierbas, hojas y semillas delicadas.
  * **Matraz de Cristal Aislado:** Para capturar gotas de rocío elemental y gemas mágicas.
* *Penalización por Error:* Si una hierba cae en el matraz o una gema ácida en la canasta, el reactivo se contamina y se destruye, restando puntos y anulando el multiplicador de combo.

### C. Multiplicador de Combo en Cadena (`combo_streak`)
* Encadenar capturas continuas del mismo tipo sin permitir que toquen el suelo eleva el multiplicador de puntos (x1 -> x2 -> x3 -> x4), acelerando el cumplimiento del objetivo.

---

## 3. Objetivos de Misión

Tres misiones concretas diseñadas para el pipeline narrativo y de gremios:

### Misión 1: "La Fórmula del Elixir Restaurador" (Misión de Lista de Ingredientes)
* **Contexto:** El destilador alquímico de Aurelius está condensando los vapores para crear el tónico restaurador. Se requieren proporciones químicas exactas antes de que los extractos se enfríen.
* **Condición de Victoria:** Recolectar una lista estricta de reactivos botánicos: 4x `green_herb`, 2x `blue_gem` y 2x gotas de rocío puro en un plazo de 45 segundos, sin atrapar ninguna bomba de sulfuro.
* **Criterios de 3 Estrellas:**
  * ⭐ **1 Estrella (Superado):** Completar la lista de reactivos antes del tiempo límite.
  * ⭐⭐ **2 Estrellas (Maestría):** Finalizar con las 3 vidas intactas (cero bombas atrapadas).
  * ⭐⭐⭐ **3 Estrellas (Perfección):** Completar la receta en menos de 28 segundos sin permitir que ningún ingrediente clave toque el suelo.

### Misión 2: "Lluvia de Ascuas en el Granero" (Misión Defensiva / Intercepción)
* **Contexto:** Un incendio en la herrería contigua está arrojando una lluvia de chispas y ascuas sobre el pajar del granero comunal. El heno seco arderá si caen demasiadas chispas.
* **Condición de Victoria:** Interceptar 25 ascuas con el cubo de arena húmeda a lo largo de 40 segundos, tolerando que un máximo de 2 ascuas toquen el piso de heno.
* **Criterios de 3 Estrellas:**
  * ⭐ **1 Estrella (Superado):** Interceptar 25 ascuas y evitar el incendio.
  * ⭐⭐ **2 Estrellas (Maestría):** 100% de intercepción aérea (cero ascuas tocan el suelo).
  * ⭐⭐⭐ **3 Estrellas (Perfección):** Cero ascuas en suelo + rescatar 3 frascos de aceite valiosos que caen entre las chispas.

### Misión 3: "Clasificación Alquímica Magistral" (Misión de Contenedor Dual)
* **Contexto:** Durante el examen de la Academia Alquímica, dos destiladores gotean de forma simultánea. El candidato debe clasificar reactivos botánicos y cristales minerales en sus respectivos contenedores al vuelo.
* **Condición de Victoria:** Clasificar correctamente 20 hojas medicinales en la canasta y 15 cristales puros en el matraz en menos de 60 segundos, cometiendo menos de 3 errores de clasificación.
* **Criterios de 3 Estrellas:**
  * ⭐ **1 Estrella (Superado):** Clasificar los 35 reactivos requeridos.
  * ⭐⭐ **2 Estrellas (Maestría):** Cero errores de contenedor (100% de precisión de clasificación).
  * ⭐⭐⭐ **3 Estrellas (Perfección):** Cero errores + sostener una racha de combo ininterrumpida de al menos x10 durante la sesión.

---

## 4. Gancho Narrativo e Integración en el Mundo

### Personaje Emisor y Locación
* **NPC:** Maestro Alquimista Aurelius / Boticaria Mirna.
* **Ubicación:** Laboratorio de Destilación de la Aldea (Overworld).
* **Activador:** Diálogo de pedido de suministros medicinales vía `DialogueManager` (`aurelius_alchemist.dialogue`).

### Grado de Obligatoriedad
* **Instancia de Trama (Main Quest):** Obligatoria en el Acto 1. Para purificar el agua del pozo envenenada por los goblins, se debe destilar con éxito la cura en la Misión 1 (*"La Fórmula del Elixir Restaurador"*).
* **Instancias Opcionales (Hub / Ayudante de Botica):** El laboratorio ofrece contratos repetibles donde el jugador procesa hierbas para obtener pociones curativas baratas y gemas elementales.

### Desbloqueos y Recompensas
* **Recompensa Narrativa / Lore:** Otorga la receta oficial de la poción curativa en el Códice y desbloquea el uso de la mesa de alquimia en la casa del jugador.
* **Recompensa Material:**
  * Primera vez: 2x `red_potion`, 1x `blue_potion`, 1x `antidote`, 50x `gold_coins`.
  * Repetible: 1x `red_potion`, 15x `gold_coins`.

---

## 5. Tabla de Progresión

| ID Misión | Título | Tipo | Desbloqueo | Modificadores Clave | Recompensa Primera Vez | Recompensa Repetible |
| :--- | :--- | :---: | :--- | :--- | :--- | :--- |
| `catch_01` | *El Elixir Restaurador* | **Main Quest** | Acto 1 (Crisis del Pozo) | Lista de 3 ingredientes, 45s | `red_potion` x2, `blue_potion` x1, 50 Oro | `red_potion` x1, 15 Oro |
| `catch_02` | *Ascuas en el Granero* | Contrato Hub | Tras completar `catch_01` | Ascuas de fuego, Defensa de suelo | `wood_log` x5, `bread` x2, 70 Oro | `bread` x1, 20 Oro |
| `catch_03` | *Clasificación Magistral* | Desafío Maestro | Acto 2 (Laboratorio de la Ciudad) | Modo doble contenedor, Viento lateral | `blue_gem` x2, Alambique Dorado (Lore), 150 Oro | `blue_potion` x1, 35 Oro |

---

## 6. Gaps Técnicos a Resolver

Al confrontar la visión de diseño con el código actual (`mg_catcher_game.gd` y `falling_item_base.gd`):

1. **Falta de Fuerzas Laterales / Dinámica de Viento en Proyectiles Descendentes:**
   * *Estado actual:* `falling_item_base.gd` solo incrementa su posición vertical linealmente (`global_position.y += speed * delta`).
   * *Requerimiento:* Incorporar un vector de aceleración o perturbación horizontal seno (`wind_offset`) para posibilitar trayectorias sinuosas o desviadas por ráfagas.
2. **Ausencia de Interfaz y Lógica de "Lista de Ingredientes" (Checklist UI):**
   * *Estado actual:* El juego solo comprueba un contador numérico escalar (`score >= target_value`) o agotamiento de tiempo.
   * *Requerimiento:* Crear una estructura de inventario de objetivos requeridos (`Dictionary: {item_id: count}`) y un panel de checklist visual en el HUD para tachar ítems a medida que son atrapados.
3. **Ausencia de Modo Contenedor Dual / Conmutación:**
   * *Estado actual:* `catcher_player.gd` solo tiene una única cesta receptora estática.
   * *Requerimiento:* Añadir estado de alternancia de receptores (ej. tipo A y tipo B con diferente color/textura) y validar el tipo de ítem impactado contra el contenedor activo.
4. **Falta de Sistema de Combos por Racha Consecutiva:**
   * *Estado actual:* Cada ítem capturado suma +1 al score sin importar el orden ni la racha.
   * *Requerimiento:* Contador `combo_streak` con multiplicador y reinicio automático al fallar o atrapar un ítem no coincidente.
5. **Evaluación de Estrellas en UI Modal:**
   * *Estado actual:* `finish(true)` no computa tiempo sobrante, vidas intactas ni precisión de ingredientes para otorgar las 3 estrellas.
