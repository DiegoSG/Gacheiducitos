# Minijuego 05: Trampolín (Ascenso Vertical de Plataformas)

## 1. Core Loop

### Mecánica Base Invariable
El minijuego es un ascenso vertical continuo de saltos acrobáticos sobre plataformas suspendidas en el aire (estilo *Doodle Jump / Icy Tower*).

* **Salto y Rebote Automático:** El personaje (`mg_trampolin_player.gd`) salta constantemente impulsado por la gravedad. Cuando sus pies colisionan de arriba hacia abajo con la superficie superior de una plataforma (`mg_trampolin_platform.tscn`), recibe un impulso de rebote vertical automático hacia arriba.
* **Control Direccional y Desplazamiento Horizontal:** El jugador utiliza las teclas de dirección (`A`/`D`, `FLECHA IZQUIERDA`/`DERECHA` o stick analógico) para maniobrar en el aire y dirigir el aterrizaje hacia la siguiente plataforma.
* **Cámara de Ascenso Unidireccional:** La cámara sigue al jugador estrictamente hacia arriba (`camera.global_position.y = min(camera.global_position.y, player.global_position.y)`). Las plataformas que quedan por debajo del margen inferior de la pantalla se destruyen (`cleanup_threshold`).
* **Condición de Caída (Game Over):** Si el jugador erra el salto y cae por debajo del borde inferior de la cámara, cae al vacío perdiendo la partida.
* **Recolección en Vuelo:** Las monedas flotan en trayectorias aéreas parabólicas, mientras que los ítems del inventario (`mg_trampolin_item.tscn`) descansan directamente sobre las plataformas y se recogen por contacto físico al aterrizar.

### Referencia al Código y Escenas Actuales
* **Escena Principal:** `res://src/minigames/mg_trampolin/mg_trampolin.tscn`
* **Script del Controlador:** `res://src/minigames/mg_trampolin/mg_trampolin.gd` (Hereda de `MinigameBase`)
* **Personaje Jugador:** `res://src/minigames/mg_trampolin/mg_trampolin_player.gd` y `mg_trampolin_player.tscn`
* **Plataforma Básica:** `res://src/minigames/mg_trampolin/mg_trampolin_platform.tscn`
* **Pickups y Coleccionables:** `res://src/minigames/mg_trampolin/mg_trampolin_coin.tscn` y `mg_trampolin_item.tscn`
* **Configurador Inspector:** `res://src/minigames/mg_trampolin/config_mg_trampolin.gd`

---

## 2. Modificadores de Sesión

Parámetros inyectados mediante `GameManager.minigame_config` para aportar variedad a las expediciones de escalada:

### A. Tipos de Plataformas con Comportamiento
1. **Plataforma de Madera Básica (`platform_wood`):** Estable y fija; soporta rebotes infinitos.
2. **Plataforma Móvil Horizontal (`platform_moving`):** Oscila de izquierda a derecha a velocidad constante, requiriendo calcular el tiempo de caída.
3. **Plataforma Quebradiza / Frágil (`platform_fragile`):** Construida de madera astillada o hielo. Soporta exactamente **un solo rebote**; se resquebraja y desvanece de inmediato, impidiendo rebotar de nuevo en ella.
4. **Plataforma con Resorte Dorado (`platform_spring`):** Posee un muelle mecánico en el centro que otorga un mega-impulso equivalente a 2.5x la altura normal de salto.
5. **Plataforma Falsa / Ilusoria (`platform_fake`):** Nube o tablón fantasma que no tiene colisión física activa; el personaje pasa a través de ella si no la identifica antes de aterrizar.

### B. Amenazas Aéreas y Corrientes de Aire
* **Aves Rapaces / Murciélagos de Cumbre (`aerial_hazard`):** Enemigos que patrullan en línea horizontal a altitudes medias. Colisionar con ellos empuja al jugador hacia abajo y cancela el impulso de salto.
* **Corrientes Térmicas Ascendentes (`thermal_updraft`):** Columnas de viento que aumentan temporalmente la sustentación del salto en tramos abiertos.

### C. Power-ups Aéreos
* **Capa Planeadora (`glider_feather`):** Al recogerla, mantener presionado salto permite planear horizontalmente a velocidad de caída muy reducida durante 4 segundos.
* **Imán de Monedas (`magnet_trinket`):** Atrae magnéticamente las monedas y gemas cercanas sin necesidad de cruzar directamente por su posición.

---

## 3. Objetivos de Misión

Tres misiones concretas diseñadas para la campaña principal y desafíos de alpinismo:

### Misión 1: "El Encendido del Faro de la Atalaya" (Misión de Altura y Cumbre Fija)
* **Contexto:** Una densa niebla mágica avanza desde la costa. El Vigía necesita que el protagonista escale la vieja atalaya hasta la cornisa superior (600 metros) para prender el faro antes de que los barcos zozobren.
* **Condición de Victoria:** Alcanzar la plataforma dorada de la cima a 600 metros de altura (`target_value = 600.0`) y tomar tierra firme sobre ella.
* **Criterios de 3 Estrellas:**
  * ⭐ **1 Estrella (Superado):** Alcanzar la plataforma de la cima del faro.
  * ⭐⭐ **2 Estrellas (Maestría):** Completar la escalada en menos de 45 segundos.
  * ⭐⭐⭐ **3 Estrellas (Perfección):** Completar el ascenso en menos de 30 segundos sin fallar ningún salto (ascenso continuo a ritmo perfecto).

### Misión 2: "El Reto del Purista (Sin Resortes)" (Misión de Restricción de Ruta)
* **Contexto:** La hermandad de guías de montaña evalúa el temple de los novatos imponiendo una regla estricta: subir 450 metros pisando exclusivamente apoyos de madera firme, sin valerse de resortes elásticos ni plataformas móviles.
* **Condición de Victoria:** Subir a 450 metros de altura sin hacer contacto con ninguna plataforma con resorte dorado ni plataforma móvil.
* **Criterios de 3 Estrellas:**
  * ⭐ **1 Estrella (Superado):** Alcanzar los 450 metros respetando la restricción de plataformas.
  * ⭐⭐ **2 Estrellas (Maestría):** Cero toques a plataformas frágiles (puros apoyos de madera sólida).
  * ⭐⭐⭐ **3 Estrellas (Perfección):** Cumplir la restricción y recolectar al menos 20 monedas de oro en el trayecto aéreo.

### Misión 3: "El Nido del Águila Imperial" (Misión de Recolección Aérea y Aterrizaje)
* **Contexto:** En los riscos más escarpados, un águila imperial custodia gemas de luz en tres salientes naturales. El explorador debe recolectarlas durante la ascensión.
* **Condición de Victoria:** Recolectar 3 gemas azules (`blue_gem`) suspendidas a 250m, 500m y 750m de altitud, y aterrizar en el nido de la cumbre (850m).
* **Criterios de 3 Estrellas:**
  * ⭐ **1 Estrella (Superado):** Recolectar las 3 gemas y alcanzar el nido cumbre.
  * ⭐⭐ **2 Estrellas (Maestría):** Esquivar a todas las aves rapaces guardianas (cero colisiones aéreas).
  * ⭐⭐⭐ **3 Estrellas (Perfección):** Cero colisiones + recolectar el 100% de las monedas suspendidas en los arcos parabólicos.

---

## 4. Gancho Narrativo e Integración en el Mundo

### Personaje Emisor y Locación
* **NPC:** Cartógrafo Real Dorian / Vigía de la Atalaya.
* **Ubicación:** Campamento Base del Desfiladero (Acceso a las Cumbres Nevadas en el Overworld).
* **Activador:** Diálogo de exploración geográfica mediante `DialogueManager` (`dorian_cartographer.dialogue`).

### Grado de Obligatoriedad
* **Instancia de Trama (Main Quest):** Obligatoria en el Acto 2. Para despejar la niebla que oculta el paso del desfiladero hacia el Templo de las Cumbres, es mandatorio encender el faro en la Misión 1 (*"El Encendido del Faro de la Atalaya"*).
* **Instancias Opcionales (Hub / Concurso de Alpinismo):** Dorian ofrece contratos de cartografía aérea que premian al jugador con mapas de tesoros y gemas preciosas.

### Desbloqueos y Recompensas
* **Recompensa Narrativa / Lore:** Despeja la niebla del mapa del Overworld en la cordillera norte y desbloquea el documento *"Cuaderno del Cartógrafo: Secretos de las Alturas"*.
* **Recompensa Material:**
  * Primera vez: 1x `blue_gem`, 1x `leather_cap` aerodinámico, 70x `gold_coins`.
  * Repetible: 1x `blue_gem`, 30x `gold_coins`.

---

## 5. Tabla de Progresión

| ID Misión | Título | Tipo | Desbloqueo | Modificadores Clave | Recompensa Primera Vez | Recompensa Repetible |
| :--- | :--- | :---: | :--- | :--- | :--- | :--- |
| `jump_01` | *El Faro de la Atalaya* | **Main Quest** | Acto 2 (Niebla del Desfiladero) | Altura 600m, Cima fija | `blue_gem` x1, Mapa Despejado, 70 Oro | `gold_coins` x25 |
| `jump_02` | *El Reto del Purista* | Contrato Hub | Tras completar `jump_01` | Solo madera sólida, Altura 450m | `wood_log` x10, `iron_ore` x3, 90 Oro | `wood_log` x4, 30 Oro |
| `jump_03` | *El Nido Imperial* | Desafío Maestro | Acto 3 (Cumbres Nevadas) | 3 Gemas en altura, Aves rapaces | `blue_gem` x3, Pluma Sagrada (Lore), 180 Oro | `blue_gem` x1, 45 Oro |

---

## 6. Gaps Técnicos a Resolver

Al comparar con el código actual (`mg_trampolin.gd` y `mg_trampolin_player.gd`):

1. **Falta de Variedad de Plataformas (Prefabs y Comportamiento):**
   * *Estado actual:* `spawn_platform()` solo instancia un único prefab estático (`mg_trampolin_platform.tscn`) o la plataforma dorada en la cima.
   * *Requerimiento:* Crear escenas y scripts específicos para:
     - Plataforma móvil (`mg_trampolin_platform_moving.tscn` con animación o desplazamiento senoidal).
     - Plataforma quebradiza (`mg_trampolin_platform_fragile.tscn` que detecte 1 contacto y se autodestruya tras 0.2s).
     - Plataforma con resorte (`mg_trampolin_platform_spring.tscn` que aplique multiplicador de salto de 2.5x).
     - Plataforma falsa (`mg_trampolin_platform_fake.tscn` sin capa de colisión sólida).
2. **Ausencia de Enemigos y Amenazas Aéreas:**
   * *Estado actual:* El único peligro de muerte es caer por debajo de la cámara.
   * *Requerimiento:* Entidad voladora patrullera (`aerial_enemy.tscn`) que recorra el ancho de la pantalla y detenga el salto del jugador en caso de choque.
3. **Rigidez de la Cámara Unidireccional:**
   * *Estado actual:* La cámara se actualiza exclusivamente hacia arriba (`if player.global_position.y < camera.global_position.y: camera.global_position.y = player.global_position.y`), impidiendo mecánicas de descenso controlado o paneos de aterrizaje cinematográfico.
4. **Cálculo y Visualización de 3 Estrellas:**
   * *Estado actual:* `_win_game()` emite victoria sin evaluar tiempo transcurrido, monedas recolectadas ni cumplimiento de restricciones de plataformas para conceder estrellas en la pantalla final.
