# Features Checklist

Este documento contiene la lista de funcionalidades y los puntos de control (checks) que deben cumplirse antes de dar una tarea por terminada.

## 🟢 Core Engine & Overworld (Completado/En proceso)
- [x] Movimiento 8 direcciones (Referencia: `player.gd`)
- [x] Cámara con límites por nivel y sincronización dinámica (Referencia: `bounded_camera.gd`)
- [x] Colliders dinámicos y visualización en editor de bordes de nivel (Referencia: `world_boundary_manager.gd`)
- [x] Manager de transiciones entre niveles con Fade, ArrivalSpawnPoints y LevelPortals (Referencia: `game_manager.gd` / `level_portal.gd` / `arrival_spawn_point.gd`)
- [x] Estandarización de Grilla 60x60 px (`tileset_60x60.png`, `core_tileset.tres`)
- [x] Plantilla de nivel limpia y autónoma (`template_level.tscn`) con Player y BoundedCamera integrados
- [x] Plantilla de prototipado de niveles legacy (`prototype_template.tscn`)
- [x] Auditoría integral: corrección de fugas de memoria, crashes en corrutinas, tipado estricto y optimización de código
- [ ] TODO: Animación de salida del portal (el personaje se desplaza desde el portal hacia el punto de llegada / arrival point)
- [x] Sistema de interacción base (Referencia: `actionable.gd`)
- [x] Puertas vs Portales: modos `PORTAL` (toque directo) y `DOOR` (interacción manual)
- [x] Lógica de Candados y Llaves en Puertas: comprobación con `Inventory`, consumo opcional de ítems y retroalimentación/diálogo de bloqueo
- [x] Estados Dinámicos de Textura: vórtice activo para portales, puerta de madera para puertas abiertas, cadenas y candado para bloqueadas/desactivadas
- [x] Sistema de Interruptores/Palancas (`SwitchInteractable`) y Activadores de Eventos
- [x] Placas de Presión y Triggers de Entrada/Salida (`PressurePlate` & `GameTrigger.ON_ENTER_AND_EXIT`)
- [x] Nuevos Recursos de Pipeline: `DoorAction` (bloquear/desbloquear/activar) y `DestroyNodeAction` (eliminar/desvanecer obstáculos)
- [x] Sistema de Salud Unificado, Muerte, Checkpoints y Respawn (`PlayerStats`, `CheckpointLevel`, `ArrivalSpawnPoint.RespawnPoint` y reversión de persistencia con `WorldStateManager`)

---

## 📌 Registro de Checkpoints / Milestones

### 🔖 Checkpoint — 28 de Agosto, 2026: *Overworld Core, Portales, Grilla 60x60 y Auditoría Integral*
- **Sistemas completados y auditados:**
  1. **Sistema de Portales y Spawns:** `LevelPortal` (salida/llegada) y `ArrivalSpawnPoint` con IDs únicos, validación de duplicados y atajo de debug F3.
  2. **WorldBoundaryManager & BoundedCamera:** Edición visual de límites en el viewport del editor con `@tool`, redibujado de bordes, sincronización por señal con la cámara y generación de colisiones sólidas en tiempo de ejecución.
  3. **Grilla Estándar:** Tileset nativo de 60x60 px (`tileset_60x60.png`) con colisiones configuradas en `core_tileset.tres`.
  4. **Auditoría y Estabilidad:** 34 correcciones aplicadas (fugas de memoria eliminadas, `queue_free()`, protección de reentradas, desconexión de señales huérfanas, tipado fuerte estricto).
  5. **Batería de Pruebas Automatizadas:** `test_portals_runner.gd`, `test_portals_transition.gd` y `test_camera_bounds_sync.gd` ejecutadas y pasando al 100%.

### 🔖 Checkpoint — 3 de Septiembre, 2026: *Puertas, Eventos Dinámicos, IA Enemiga y Sistema de Loot*
- **Sistemas completados y auditados:**
  1. **Puertas y Candados:** `LevelPortal` con modos Portal y Puerta cerrada/bloqueada, requerimiento de llaves desde `Inventory`, consumo opcional y feedback con `DialogueManager`.
  2. **Interactables y Triggers de Pipeline:** `SwitchInteractable` (palancas persistentes), `PressurePlate` (placas de presión), `DoorAction` y `DestroyNodeAction` conectados a `GameTrigger`.
  3. **IA de Enemigos en Overworld:** `GenericEnemy` con máquina de estados (Idle, Chasing, Lose Target, Return), alertas globales en `GameManager` (`alert_state_changed`).
  4. **Sistema de Recompensas y Loot:** `LootDropComponent` para entidades con porcentajes de drop de items y spawn de `PickupItem`.
  5. **Batería de Pruebas Automatizadas:** `test_doors_and_events_runner.gd`, `test_alert_peace_system_runner.gd` y `test_enemy_loot_runner.gd` ejecutadas y pasando al 100%.

### 🔖 Checkpoint — 3 de Septiembre, 2026: *Framework de Minijuegos, Congelamiento y Retorno Universal*
- **Sistemas completados y auditados:**
  1. **Framework y Ciclo de Vida (`MinigameBase`):** Clase base con recolección de recompensas en sesión (`add_reward`), señal desacoplada `game_finished` y congelamiento total de físicas/timers (`get_tree().paused = true`).
  2. **Feedback Visual de Fin de Partida:** Pantalla desacoplada de Victoria/Derrota (`_result_ui`) con soporte para resoluciones dinámicas, desglose de loot, botón "Continuar" interactivo y atajos (`ESPACIO`, `ENTER`, `ESC`).
  3. **Integración con Pipeline de Eventos:** Triggers unificados con `GameTrigger` + `MinigameAction` y prefab reutilizable `minigame_interactable.tscn`. Eliminación total de triggers legacy (`minigame_trigger.gd`).
  4. **Retorno al Overworld y Spawns Condicionales:** `GameManager.complete_minigame()` realiza transferencia oficial de items al `Inventory` y retorno con `ScreenFader` a `win_spawn_id` o `lose_spawn_id`.
  5. **Nivel de Pruebas Multi-Trigger (`test_minigame_flow.tscn`):** 5 triggers independientes configurados y validados para cada uno de los 5 minijuegos (`Catcher`, `Excavation`, `Runner`, `Smasher`, `Trampolin`).
  6. **Estructura y Limpieza del Proyecto:** Eliminación de archivos temporales/autosaves, estandarización a `snake_case` y creación de la skill oficial `godot-project-structure`.
  7. **Batería de Tests Automatizados:** `test_minigame_flow_runner.gd` ejecutada y validando el 100% de los flujos en Godot 4.6 headless.


### 🔖 Checkpoint — 13 de Septiembre, 2026: *Ajustes de Minijuegos, Feedback Visual de Loot, Gamepad e Inventario del Jugador*
- **Sistemas completados y auditados:**
  1. **Feedback Visual de Loot y HUD del Jugador (`PlayerHUD`):**
     * Sistema de iconos voladores (`LootFeedbackManager` y `LootFlyIcon`) con trayectoria parabólica/descendente hacia el icono del inventario.
     * Activación automática al recolectar `PickupItem`, abrir cofres (`chest.gd`) o regresar victorioso de cualquier minijuego.
     * Desacoplamiento total: `InventoryUI` ahora forma parte del `Player` a través de `PlayerHUD`, pausando el árbol de juego (`get_tree().paused = true`) al abrirse y reanudando al cerrarse.
  2. **Soporte Nativo de Joystick / Gamepad:**
     * Mapeo en `project.godot` de Stick Analógico Izquierdo, D-Pad, Botón A (Acción/Salto), Botón B (Cancelar/Agache), Botón X (Ataque), Botón Y (Inventario) y Botón Pause (Start).
     * Integración total con Overworld (`player.gd`) y minijuegos.
  3. **Ajustes de Minijuegos:**
     * **Runner 2D:** Aceleración progresiva configurable (`speed_increase_interval`, `speed_increase_amount`), recarga de munición con distanciamiento progresivo (`ammo_spawn_initial_distance`, `ammo_spawn_distance_multiplier`, +1 bala), pool de ítems y separación inteligente contra solapamientos.
     * **Catcher:** Retardo de 3.0 segundos en el suelo con parpadeo, recolección al caminar sobre el piso, pérdida de vida al expirar ítems críticos y pool de ítems.
     * **Trampolín:** Ítems de inventario reposando físicamente sobre plataformas/trampolines (distintos a las monedas aéreas), recolectados por contacto directo.
     * **Excavación:** Bombas ambientales con gravedad, deslizamiento y empuje horizontal que detonan en 3x3 al impactar suelo, obstáculos o jugador; bombas manuales estáticas colocadas con espacio sostenido (0.35s) con cuenta regresiva de 4s y radio letal de 3x3 que destruye terreno y causa muerte al jugador si se queda dentro; sustitución visible de tierra por ítems de inventario y munición de bomba manual si `deliver_items = true`.
  4. **Guía de Creación de Niveles Overworld:**
     * Creada `design/Guia_Creacion_Niveles.md` documentando paso a paso la creación de mapas desde cero usando `prototype_template.tscn` para el Vertical Slice.

## 🟡 Feature: Minijuego A (Excavación)
- [x] Generador Procedimental (Autómatas Celulares) (Ref: `Minijuego_Supaplex.md`)
- [x] Algoritmo de Validación de Conectividad (Flood Fill) (Ref: `Minijuego_Supaplex.md`)
- [x] Motor de Grid y Lógica de Excavación (Ref: `Minijuego_Supaplex.md`)
- [x] Gravedad de Piedras (Caída y Deslizamiento) (Ref: `Minijuego_Supaplex.md`)
- [x] **Elementos Interactivos y Bombas:**
  - [x] Bombas ambientales con física de gravedad, empuje y detonación 3x3 al impactar.
  - [x] Bombas manuales con plantado estático (`ui_accept` sostenido 0.35s), cuenta atrás de 4s y explosión letal 3x3.
  - [x] Tipos de bloque: Muros irrompibles y salida inmune a bombas.
  - [x] Poblar terreno visible con ítems de inventario y munición de bombas manuales (`deliver_items`).
- [ ] **Edición Manual de Niveles:**
  - [ ] Soporte para cargar niveles prediseñados a mano en lugar de sólo procedimental.
  - [ ] TileMap / Grid de tiles para "pintar" tierra, piedras, muros y objetos directamente desde el editor de Godot.
- [ ] **Enemigos y Sigilo (Siguiente iteración):**
  - [ ] IA de Enemigo ciego guiado por sonido (excavación vs explosiones).
  - [ ] Sistema de sigilo en túneles vacíos.

## 🟢 Feature: Minijuego Runner (Estilo Dino 2D Side-Scroller) (Completado)
- [x] **Mecánica Core 2D:**
  - [x] Perspectiva lateral 2D (Side-scroller) con física de salto parabólico (`ui_up`/`ui_accept`/`Espacio`), caída rápida (*fast-fall*) y agache/slide (`ui_down`).
  - [x] Conmutación limpia de colisionadores (Stand vs Duck) para pasar bajo obstáculos aéreos con legibilidad 100% intuitiva.
  - [x] Scroll continuo de suelo con indicadores de velocidad y desplazamiento de pista.
  - [x] Aumento progresivo de velocidad cada X metros (`speed_increase_interval`, `speed_increase_amount`).
  - [x] Pickups de munición (+1 bala) con distancia creciente progresiva.
  - [x] Generación procedural de obstáculos terrestres bajos (salto), aéreos suspendidos (agache) y enemigos frontales.
  - [x] Condiciones de victoria configurables: Por Distancia (`WIN_BY_DISTANCE`) o por Objeto Clave (`WIN_BY_OBJECT`) con rango aleatorio `[min, max]`.
  - [x] Catálogo y patrones rítmicos de monedas: Líneas de 1, 2, 3 o 4 monedas, patrón en V y patrón en V invertida (arco parabólico de salto).
  - [x] Anti-solapamiento inteligente para asegurar legibilidad en carrera.
  - [x] Aparición de ítems aleatorios del pool de inventario con recolección directa hacia `MinigameBase.add_reward()`.
  - [x] Integración completa con la escena unificada de pruebas `test_minigame_flow.tscn` y suite automatizada `test_runner_mechanics.gd`.

## 🟡 Feature: Minijuego Trampolín (Sistema de Temas e Ítems)
- [x] Ítems de inventario reposando sobre plataformas y trampolines (recolección por contacto físico).
- [ ] **Sistema de Temas Visuales:**
  - [ ] Selector/recurso de tema para intercambiar fondos dinámicamente (cielo, noche, espacio, cueva).
  - [ ] Variaciones de textura/estilo para las plataformas según el tema activo.
  - [ ] Balance de tipos de plataformas (estáticas, móviles, rebotadoras frágiles).

## 🟡 Feature: Minijuego Smasher (Temas y Puntos de Salida/Entrada)
- [ ] **Sistema de Temas Visuales:**
  - [ ] Fondos intercambiables por configuración/recurso.
  - [ ] Personalización temática de los puntos / dianas a golpear.
- [ ] **Puntos de Entrada y Salida Configurables:**
  - [ ] Definición explícita de spawners (puntos de entrada de dianas) y zonas de escape/salida.

## 🟡 Feature: Minijuego Catcher (Temas, Balances y Suelo)
- [x] Retardo de permanencia de ítems en el suelo (3.0s) con parpadeo visual.
- [x] Recolección de ítems en el suelo por contacto del jugador.
- [x] Penalización de vida inmediata al expirar ítems críticos en el suelo.
- [x] Pool de recompensas de inventario configurable.
- [ ] **Sistema de Temas Visuales:**
  - [ ] Fondos intercambiables por configuración/recurso.

## 🟢 Feature: Feedback de Loot, Cofres y Minijuegos (LootToastStack) (Completado)
- [x] **Notificaciones Tipo Toast al Lado del Inventario (`LootToastStack`):**
  - [x] Al recoger `PickupItem`, abrir cofre (`chest.gd`) o finalizar minijuego (`MinigameBase.add_reward`), desplegar inmediatamente una fila de toast junto a la mochila.
  - [x] Estructura visual limpia: `[Icono] x N [Nombre]` con fondo oscuro semi-transparente y bordes redondeados.
  - [x] Apilamiento dinámico: Ítems idénticos o monedas consecutivas incrementan el contador (`x 1` -> `x 2`) con un scale punch visual y reinician el temporizador a 2.5s sin duplicar filas.
  - [x] Soporte completo de Monedas de Oro (`gold_coins`) mostrando `[🪙] Monedas de Oro x N` y apilándose automáticamente.
  - [x] Eliminación de la animación de iconos voladores cruzando la pantalla para evitar polución visual y dar feedback instantáneo.
  - [x] Temporizador de permanencia de 2.5s con desvanecimiento suave (fade-out de opacidad) y limpieza automática de memoria.
- [ ] **TODO Diseño de UI (Tarea Asignada para Sesión de Diseño):**
  - [ ] Asignar lugares definitivos a todos los elementos del HUD (esquinas, slots, área dedicada del inventario y barra de accesos).
  - [ ] Diseño de menú/barra de acceso rápido (Hotbar / Quick-access).

## 🟢 Feature: Arquitectura de Inventario Unificado y Control de Pausa (Completado)
- [x] **Desacoplamiento de Niveles e Integración al Player:**
  - [x] Mover `InventoryUI` para que forme parte del `Player` mediante el componente `PlayerHUD`.
  - [x] Eliminada la necesidad de instanciar `InventoryUI` a mano en los niveles (limpiado en `overworld.tscn`).
  - [x] **Pausa de Juego:** Pausar el árbol de nodos (`get_tree().paused = true`) al abrir el inventario (`toggle_inventory()`) y reanudar al cerrar (`process_mode = PROCESS_MODE_ALWAYS` para el menú).
- [ ] **Menú de Acceso Rápido (Hotbar):** Barra persistente para uso rápido de consumibles o llaves en Overworld (vinculada a la tarea de diseño de UI).

## 🟢 Feature: Soporte Nativo para Joystick / Gamepad (Completado)
- [x] Mapeo completo en `InputMap` (D-Pad y Stick analógico izquierdo para movimiento de jugador con deadzone).
- [x] Botones de interacción (Cruz/A para interactuar y saltar, Círculo/B para cancelar y deslizarse, Cuadrado/X para atacar y disparar, Triángulo/Y para inventario, Botón Start para pausar).
- [x] Soporte en todos los minijuegos y Overworld.

---

## 🎯 Próximo Gran Hito: Vertical Slice & Guía Paso a Paso de Creación de Niveles
- [x] **Documentación Guía de Creación de Niveles Overworld Paso a Paso:**
  - [x] Creada `design/Guia_Creacion_Niveles.md` cubriendo la creación desde `prototype_template.tscn`, configuración de colisiones, portales, puertas con llave, cofres, drops de enemigos, triggers de minijuegos y NPCs con diálogos.
- [ ] Creación manual guiada de dos niveles interconectados como demostración del Vertical Slice (realizada por el usuario siguiendo la guía).

---

## 📌 Milestone: Diseño Técnico de Misiones para Minijuegos (Framework de 4 Capas)
- [x] **Framework de 4 Capas Documentado (`docs/design/misiones/00-sistema-general.md`):**
  - [x] Core loop, Modificadores de sesión, Objetivo de misión (3 estrellas) y Gancho narrativo.
  - [x] Estandarización de `MissionDefinition` con integración a `GameManager`, `NarrativeManager`, `Inventory` e `ItemDatabase`.
  - [x] Especificación técnica del sistema de feedback visual de loot en HUD (`LootToastStack` junto al icono de inventario, `[Icono] x N`, 2.5s con fade-out).
- [x] **Documentación Técnica Específica por Minijuego:**
  - [x] Smasher (`docs/design/misiones/01-smasher.md`): Whack-a-mole, bichos blindados/trampa, misiones de precisión y gaps técnicos identificados.
  - [x] Excavación (`docs/design/misiones/02-excavacion.md`): Física de rocas/bombas, medidor de oxígeno/pasos, misiones de extracción y rescate.
  - [x] Runner (`docs/design/misiones/03-runner.md`): Rutas altas/bajas, enemigos con reacción estricta, checkpoints narrativos y escolta.
  - [x] Catcher (`docs/design/misiones/04-catcher.md`): Viento lateral, contenedor dual, checklist de ingredientes y misiones defensivas.
  - [x] Trampolín (`docs/design/misiones/05-trampolin.md`): Plataformas móviles/quebradizas/resorte, cumbres fijas y restricciones de ruta.

---

### 🔖 Checkpoint — 14 de Septiembre, 2026: *Integración Visual de Personaje en Minijuegos, Arañas en Smasher y Llaves de Inventario en Portales*
- **Sistemas y Mejoras Implementadas:**
  1. **Integración del Nuevo Player en Minijuegos:**
     - `MG_Catcher`: Reemplazo del placeholder de icono por `player_down.png` y cambio dinámico a `player_side.png` con `flip_h` según el desplazamiento horizontal.
     - `MG_Runner`: Reemplazo del placeholder por `player_side.png` orientado al frente de carrera, eliminación de tintes de color (`modulate = Color.WHITE`) y ajuste de escala a colisiones de carrera y agache.
     - `MG_Trampolín`: Integración del nuevo sprite del personaje respondiendo con `player_up.png`, `player_down.png` y `player_side.png` (`flip_h`) según fase de salto y movimiento lateral.
     - `MG_Excavación`: Renderizado directo de la textura `player_down.png` en la celda del jugador en sustitución de las figuras primitivas.
  2. **MG_Smasher — Reemplazo de Puntos por Arañas:**
     - Sustitución de `icon_red.png` por el sprite oficial `spider_enemy.png`.
     - Calibración de la rotación y orientación angular ($-\pi/2$) para que la cabeza y cuerpo de la araña apunten hacia adelante a lo largo de su trayectoria curva.
  3. **Sistema de Portales y Puertas con Llave (`LevelPortal`):**
     - Nueva propiedad `@export var key: ItemData` en inspector para arrastrar y soltar recursos de llave (`.tres`).
     - Activación automática de `is_locked = true` al asignar un ítem llave.
     - Soporte para consumo opcional del ítem (`consume_key: bool`) descontando 1 unidad de `Inventory` si está activado, o conservándolo si no.
     - Actualización visual automática y emisión de señales `unlocked` / `locked`.
  4. **Resolución de Conflictos de Cámara:**
     - Eliminación de nodos duplicados obsoletos `Camera2D` bajo `Player` en los niveles del overworld, permitiendo que el `Player` gestione de manera autónoma su propia `BoundedCamera`.




