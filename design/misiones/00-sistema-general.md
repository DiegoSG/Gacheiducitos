# Sistema General de Misiones para Minijuegos (RPG-G)

## 1. Visión General y Objetivos de Diseño

El propósito de este framework es transformar los 5 prototipos de minijuegos independientes existentes en el proyecto (**Smasher**, **Excavación**, **Runner**, **Catcher** y **Trampolín**) en **misiones estructuradas, rejugables y orgánicamente integradas** en la experiencia RPG principal de **RPG-G (Godot 4.6)**.

### Objetivos Clave
1. **Unificación Arquitectónica:** Todos los minijuegos operan bajo el mismo contrato de ciclo de vida (`MinigameBase`), puente de datos (`GameManager.minigame_config`) y retorno al Overworld.
2. **Eliminación del Puntaje Abstracto Vacío:** Se sustituye el simple "sobrevive X segundos" o "suma puntos genéricos" por **objetivos narrables y contextualizados** (ej. extraer una reliquia arqueológica, clasificar ingredientes para un antídoto, escapar de un bloqueo fronterizo).
3. **Rejugabilidad y Variedad Dinámica:** El mismo minijuego base ofrece experiencias distintas gracias a la rotación de modificadores de sesión (mecánicas, físicas, amenazas y layouts).
4. **Desacoplamiento Narrativo:** La narrativa se cuenta **afuera** del minijuego (mediante NPCs en el Hub y Overworld con diálogos en `DialogueManager`), mientras que el minijuego actúa como prueba de habilidad que desbloquea lore, ítems y progreso global.

---

## 2. El Framework de 4 Capas

Cada misión de minijuego se construye componiendo cuatro capas estrictamente definidas:

```
┌─────────────────────────────────────────────────────────────┐
│  CAPA 4: GANCHO NARRATIVO (Overworld / Hub / NPCs)           │
│  • Quien asigna, contexto, justificación del desafío         │
│  • Consecuencia narrativa y recompensas en el mundo         │
├─────────────────────────────────────────────────────────────┤
│  CAPA 3: OBJETIVO DE MISIÓN (Reglas de Victoria y Estrellas)│
│  • Condición de éxito específica y narrable                 │
│  • Criterios de evaluación de 1, 2 y 3 estrellas            │
├─────────────────────────────────────────────────────────────┤
│  CAPA 2: MODIFICADORES DE SESIÓN (Variabilidad y Dificultad)│
│  • Físicas, tipos de entidades, penalizadores, layouts      │
│  • Configuración inyectada vía GameManager.minigame_config  │
├─────────────────────────────────────────────────────────────┤
│  CAPA 1: CORE LOOP (Mecánica Base Invariable)               │
│  • Controles, lógica intrínseca y bucle de interacción      │
│  • Hereda de MinigameBase y se ejecuta en aislamiento        │
└─────────────────────────────────────────────────────────────┘
```

### Capa 1: Core Loop (Mecánica Base Invariable)
Representa la física y controles fundamentales del minijuego. **No cambia entre partidas**. Por ejemplo:
* *Smasher:* Tap/Click sobre objetivos que emergen y desaparecen.
* *Excavación:* Movimiento ortogonal en grilla, cavar tierra, gravedad de piedras/bombas.
* *Runner:* Avance lateral continuo con salto, agache/slide y disparo.
* *Catcher:* Movimiento horizontal para interceptar objetos descendentes.
* *Trampolín:* Saltos parabólicos verticales continuos rebotando sobre plataformas.

### Capa 2: Modificadores de Sesión (Variaciones Dinámicas)
Parámetros inyectados al iniciar la sesión que alteran las condiciones de juego sin cambiar el core:
* Variantes de enemigos o entidades (ej. bichos blindados, bombas trampa, ascuas).
* Restricciones de recursos (oxígeno, límite de saltos, munición reducida, límite de pasos).
* Peligros ambientales (viento lateral, gases tóxicos, plataformas falsas, aceleración).
* Estructura de nivel (generador procedural con semilla vs. layouts artesanales curados).

### Capa 3: Objetivo de Misión (Condición de Victoria y 3 Estrellas)
Define qué constituye una victoria válida y qué evalúa el desempeño:
* **Condición de Victoria Primaria:** Narrable y clara (ej. "Llega al metro 1200", "Extrae el Mapa Antiguo", "Reúne 5 Hierbas Verdes").
* **Evaluación de Rendimiento (1 a 3 Estrellas):**
  * ⭐ **1 Estrella (Superado):** Cumplir el objetivo básico de la misión.
  * ⭐⭐ **2 Estrellas (Maestría Técnica):** Superar el reto con solvencia (tiempo ajustado, vida restante ≥ 2, precisión ≥ 80%).
  * ⭐⭐⭐ **3 Estrellas (Perfección / Hazaña):** Ejecución impecable (cero daño, sin fallos, tiempo récord o recolección del 100% de coleccionables secretos).

### Capa 4: Gancho Narrativo (Overworld / Hub Integration)
El puente con el mundo principal:
* **NPC Emisor:** Personaje con identidad que solicita la ayuda (ej. Barnaby, Capataz Minero, Alquimista).
* **Diálogo de Activación:** Archivos `.dialogue` procesados por `DialogueManager`.
* **Grado de Obligatoriedad:**
  * *Main Quest (Obligatoria):* Bloquea el avance de la trama principal hasta completarse con al menos 1 estrella.
  * *Side Quest / Contrato de Hub (Repetible):* Opcional, accesible desde tablones o NPCs para farmear recursos, desbloquear lore o ganar cosméticos.
* **Recompensas Narrativas y Materiales:** Transferencia a `Inventory` mediante `ItemDatabase`, banderas en `GameVariables` y entradas de códice/lore.

---

## 3. Arquitectura y Mapeo con Sistemas Reales del Proyecto

Este diseño se ancla 100% en las clases, singletons y escenas ya implementadas en el repositorio:

| Sistema del Framework | Clase / Nodo en Proyecto | Ruta en Repositorio | Responsabilidad |
| :--- | :--- | :--- | :--- |
| **Controlador Global** | `GameManager` (Autoload) | `src/core/game_manager.gd` | Transición entre escenas, almacenamiento de `minigame_config`, retorno al Overworld y orquestación de recompensas. |
| **Ciclo de Vida Minijuego**| `MinigameBase` | `src/minigames/minigame_base.gd` | Pausa en fin de partida, buffer local `session_rewards`, modal de resultados y señal `game_finished`. |
| **Estado y Quests** | `GameVariables` (Autoload) | `src/core/game_variables.gd` | Gestión de `quests` ("active", "completed") y `flags` narrativos globales. |
| **Inventario** | `Inventory` (Autoload) | `src/core/inventory.gd` | Almacenamiento real de ítems obtenidos (`add_item()`). |
| **Base de Datos de Ítems** | `ItemDatabase` (Autoload) | `src/core/item_database.gd` | Registro y validación de recursos `ItemData` desde `data/items/`. |
| **Disparadores de Nivel** | `GameTrigger` + `MinigameAction` | `src/core/pipeline/game_trigger.gd` y `actions/minigame_action.gd` | Interacción en Overworld que inyecta parámetros y lanza el minijuego. |
| **Entidades y Diálogos** | `SimpleNPC` + `DialogueManager` | `src/shared/entities/simple_npc.gd` y `addons/dialogue_manager/` | Emisión de conversaciones previas y posteriores a la misión. |
| **Feedback Visual de Botín**| `LootFeedbackManager` + HUD | `src/ui/loot_feedback/loot_feedback_manager.gd` | Animación de entrega de ítems hacia el inventario en el Overworld. |

---

## 4. Estructura Estandarizada de Misión (`MissionDefinition`)

Para formalizar cada misión sin duplicar código, se define el esquema de datos estándar que consume el sistema:

```gdscript
# Estructura conceptual de configuración de misión
{
    "id": "smasher_m01_barnaby",
    "minigame_type": "smasher",            # "smasher" | "excavation" | "runner" | "catcher" | "trampolin"
    "scene_path": "res://src/minigames/mg_smasher/mg_smasher_game.tscn",
    "title": "La Plaga del Invernadero",
    "client_npc_id": "npc_barnaby",
    "is_mandatory": true,                  # true = Main Quest, false = Side / Hub Contract
    "quest_id": "quest_greenhouse_infestation",
    "prerequisite_flags": {},              # Ej. {"met_barnaby": true}
    
    # Capa 2: Modificadores inyectados en GameManager.minigame_config
    "config": {
        "game_mode": "COUNT",
        "target_value": 20,
        "initial_speed": 140.0,
        "final_speed": 280.0,
        "lives": 3,
        "trap_insects_enabled": true,
        "layout_preset": "grid_3x3"
    },
    
    # Capa 3: Criterios de Evaluación de Rendimiento
    "star_criteria": {
        "star_1": {"desc": "Aplastó 20 orugas de plaga", "check": "target_reached"},
        "star_2": {"desc": "Terminó con al menos 2 vidas restantes", "min_lives": 2},
        "star_3": {"desc": "Precisión superior al 85% sin golpear trampas", "min_accuracy": 0.85, "trap_hits": 0}
    },
    
    # Capa 4: Recompensas
    "rewards_first_clear": {
        "items": {"green_herb": 3, "antidote": 1},
        "gold": 50,
        "lore_entry": "bestiary_caterpillar_01",
        "set_flags": {"greenhouse_cleared": true}
    },
    "rewards_repeatable": {
        "items": {"green_herb": 1},
        "gold": 15
    }
}
```

---

## 5. Estandarización de las 3 Estrellas y Pantalla de Resultados

Cada minijuego evaluará al llamar a `finish(success)` el cumplimiento de los 3 niveles de logro:

1. **⭐ Nivel 1 (Supervivencia / Finalización):** Garantiza el progreso narrativo y la entrega de la recompensa básica.
2. **⭐⭐ Nivel 2 (Eficiencia Técnica):** Demuestra dominio de la mecánica central (gestión de vidas, tiempo límite o consumo de recursos). Otorga recompensas intermedias (monedas extra o consumibles).
3. **⭐⭐⭐ Nivel 3 (Perfección / Excelencia):** Desafío de alto rendimiento (sin recibir daño, 100% de precisión, o rutas secretas). Otorga desbloqueos exclusivos (entradas de lore raras, equipamiento cosmético o recetas alquímicas avanzadas).

### Pantalla Modal Unificada
Se actualizará `MinigameBase._show_result_screen()` para que:
* Muestre los 3 iconos de estrellas animadas (vaciadas o llenas según el resultado).
* Desglose los requisitos cumplidos y fallidos.
* Enumere con claridad los ítems y recompensas acumuladas en `session_rewards`.
* Indique claramente si se batió el récord personal o si fue superada por primera vez.

---

## 6. Sistema de Modificadores y Escalado de Dificultad

Los modificadores rotan en las misiones repetibles del Hub en base a rangos de dificultad:

| Rango de Misión | Nivel Sugerido | Multiplicador de Desafío | Tipos de Modificadores Combinados |
| :---: | :---: | :---: | :--- |
| **Rango D (Novato)** | Inicio del juego | x1.0 | 0 a 1 modificador leve (velocidad estándar, sin penalizadores agresivos). |
| **Rango C (Adepto)** | Acto 1 Medio | x1.25 | 1 modificador de entidad + 1 restricción leve (ej. bichos blindados o viento suave). |
| **Rango B (Veterano)**| Acto 2 | x1.5 | 2 modificadores combinados + presencia de trampas letales. |
| **Rango A (Maestro)** | Acto 3 | x1.85 | Restricción de tiempo severa + físicas adversas + enemigos de reacción obligatoria. |
| **Rango S (Mítico)** | Post-game / Opcional| x2.2 | Supervivencia extrema, 1 sola vida o límite de recursos mínimo absoluto. |

---

## 7. Sistema de Ganchos Narrativos y Hub de Misiones

### Asignación de Misiones
1. **Misiones de Historia (Main Quests):**
   * Disparadas por puntos críticos del Overworld (`GameTrigger` en puertas de castillos, túneles bloqueados, trampas de jefes).
   * Obligatorias: No se puede cruzar la zona sin superarlas (1 estrella mínima).
2. **Misiones Secundarias y Contratos (Hub):**
   * Asignadas por NPCs residentes en el poblado central o desde el **Tablón de Anuncios de la Posada**.
   * Cada contrato presenta un contexto justificativo (ej. "Falta de madera en el aserradero", "Plaga en el huerto comunal", "Rescate de herramientas en la vieja mina").
   * Se pueden repetir indefinidamente para farmear materiales básicos con recompensas balanceadas.

### Formatos de Recompensa Estandarizados
* **Recursos Materiales:** Ítems reales del `ItemDatabase` (`iron_ore`, `wood_log`, `green_herb`, `red_potion`, `blue_gem`).
* **Moneda de Oro:** Incremento en el contador de dinero del jugador.
* **Fragmentos de Códice / Lore:** Textos que revelan trasfondo del mundo y debilidades de enemigos (leíbles en la biblioteca o menú de pausa).
* **Desbloqueos de Acceso:** Banderas de `GameVariables` que abren puertas (`door_action`), habilitan nuevos diálogos con NPCs o bajan puentes levadizos.

---

## 8. Especificación Técnica: Feedback Visual de Loot en HUD

### Diagnóstico del Problema Actual
Actualmente, `LootFeedbackManager` anima un icono volador (`LootFlyIcon`) que vuela desde la posición del pickup hacia el icono de inventario del HUD y se desvanece de golpe al impactar. El usuario ha señalado con precisión que **el refuerzo visual es pobre e insuficiente** para transmitir el valor de lo recolectado.

### Solución Diseñada: `LootToastStack` (Cola de Notificación Descendente)
Se diseñará e integrará un componente de UI persistente en el HUD del jugador (`src/ui/loot_feedback/player_hud.tscn`) posicionado inmediatamente a la derecha o debajo del icono del inventario:

```
┌─────────────────────────────────────────────────────────────┐
│  [HUD - Esquina Superior Izquierda]                         │
│                                                             │
│   [🎒 INVENTARIO]                                           │
│       │                                                     │
│       ├──► 🍞 [Pan Crujiente]      x 1      (Fading out...) │
│       ├──► 🌿 [Hierba Verde]       x 3      (2.5s visible)  │
│       └──► 💎 [Gema Azul]          x 1      (Nuevo!)        │
└─────────────────────────────────────────────────────────────┘
```

#### Especificaciones de Comportamiento:
1. **Pila Dinámica Vertical:** Los ítems recibidos (tras cofres, pickups o al regresar de un minijuego vía `GameManager.complete_minigame()`) se agregan a un contenedor vertical (`VBoxContainer`).
2. **Apilamiento Inteligente (`x N`):** Si ingresa un ítem que ya se encuentra en pantalla mostrando su toast, el contador numérico se incrementa (ej. `x 1` pasa a `x 2`) y se reinicia el temporizador de permanencia, realizando un pequeño pop de escala (`Vector2(1.2, 1.2) -> Vector2(1.0, 1.0)`).
3. **Temporizador y Desvanecimiento:**
   * Cada toast permanece visible durante **2.5 segundos**.
   * Durante los últimos 0.4 segundos, ejecuta una interpolación de opacidad (`modulate.a: 1.0 -> 0.0`) y desplazamiento lateral sutil antes de liberar el nodo (`queue_free()`).
4. **Diseño de Fila del Toast:**
   * Miniatura de icono (`TextureRect`, 24x24 px con `expand_mode = IGNORE_SIZE`).
   * Nombre del ítem con tipado legible (`Label`, font size 14, color blanco con contorno sutil).
   * Multiplicador en color dorado o verde brillante (`Label`, font size 14, estilo `x 3`).
   * Panel semi-transparente de fondo con bordes redondeados (`StyleBoxFlat`, color `#000000AA`).

Esta especificación se incorporará a la implementación técnica posterior a la aprobación del diseño.
