# Features Checklist

Este documento contiene la lista de funcionalidades y los puntos de control (checks) que deben cumplirse antes de dar una tarea por terminada.

## 🟢 Core Engine & Overworld (Completado/En proceso)
- [x] Movimiento 8 direcciones (Referencia: `player.gd`)
- [x] Cámara con límites por nivel y sincronización dinámica (Referencia: `bounded_camera.gd`)
- [x] Colliders dinámicos y visualización en editor de bordes de nivel (Referencia: `world_boundary_manager.gd`)
- [x] Manager de transiciones entre niveles con Fade, ArrivalSpawnPoints y LevelPortals (Referencia: `game_manager.gd` / `level_portal.gd` / `arrival_spawn_point.gd`)
- [x] Estandarización de Grilla 60x60 px (`tileset_60x60.png`, `core_tileset.tres`)
- [x] Plantilla de prototipado de niveles (`prototype_template.tscn`)
- [x] Auditoría integral: corrección de fugas de memoria, crashes en corrutinas, tipado estricto y optimización de código
- [ ] TODO: Animación de salida del portal (el personaje se desplaza desde el portal hacia el punto de llegada / arrival point)
- [x] Sistema de interacción base (Referencia: `actionable.gd`)
- [x] Puertas vs Portales: modos `PORTAL` (toque directo) y `DOOR` (interacción manual)
- [x] Lógica de Candados y Llaves en Puertas: comprobación con `Inventory`, consumo opcional de ítems y retroalimentación/diálogo de bloqueo
- [x] Estados Dinámicos de Textura: vórtice activo para portales, puerta de madera para puertas abiertas, cadenas y candado para bloqueadas/desactivadas
- [x] Sistema de Interruptores/Palancas (`SwitchInteractable`) y Activadores de Eventos
- [x] Placas de Presión y Triggers de Entrada/Salida (`PressurePlate` & `GameTrigger.ON_ENTER_AND_EXIT`)
- [x] Nuevos Recursos de Pipeline: `DoorAction` (bloquear/desbloquear/activar) y `DestroyNodeAction` (eliminar/desvanecer obstáculos)

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


## 🟡 Feature: Minijuego A (Excavación)
- [x] Generador Procedimental (Autómatas Celulares) (Ref: `Minijuego_Supaplex.md`)
- [x] Algoritmo de Validación de Conectividad (Flood Fill) (Ref: `Minijuego_Supaplex.md`)
- [x] Motor de Grid y Lógica de Excavación (Ref: `Minijuego_Supaplex.md`)
- [x] Gravedad de Piedras (Caída y Deslizamiento) (Ref: `Minijuego_Supaplex.md`)
- [ ] **Edición Manual de Niveles:**
  - [ ] Soporte para cargar niveles prediseñados a mano en lugar de sólo procedimental.
  - [ ] TileMap / Grid de tiles para "pintar" tierra, piedras, muros y objetos directamente desde el editor de Godot.
- [ ] **Elementos Interactivos y Bloqueos:**
  - [ ] Sistema de Bombas (colocación, temporizador y explosión 3x3).
  - [ ] Tipos de Muro: Muros irrompibles vs Muros rompibles por bombas.
  - [ ] Trampas de Bloqueo (One-way: permiten paso en un sentido pero bloquean el regreso).
- [ ] **Objetos y Misión:**
  - [ ] Colocación de ítems de misión (raíces, rescate) y loot (monedas, consumibles).
  - [ ] Reglas de riesgo/recompensa.
  - [ ] Condición de salida activada tras cumplir objetivos.
- [ ] **Enemigos y Sigilo (Siguiente iteración):**
  - [ ] IA de Enemigo ciego guiado por sonido (excavación vs explosiones).
  - [ ] Sistema de sigilo en túneles vacíos.

## 🟡 Feature: Minijuego Runner (Estilo Dinosaurio Google 2D)
- [ ] **Mecánica Core 2D:**
  - [ ] Perspectiva lateral 2D (Side-scroller) en línea recta con salto / agache al estilo Dinosaurio de Google.
  - [ ] Scroll continuo de suelo con aceleración progresiva de velocidad.
  - [ ] Generación procedural o por patrones de obstáculos terrestres y aéreos.
  - [ ] Sistema de puntuación por distancia recorrida y multiplicadores.

## 🟡 Feature: Minijuego Trampolín (Sistema de Temas)
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

## 🟡 Feature: Minijuego Catcher (Temas, Balances y Catálogo de Objetos)
- [ ] **Sistema de Temas Visuales:**
  - [ ] Fondos intercambiables por configuración/recurso.
- [ ] **Catálogo y Configuración de Objetos Caídos:**
  - [ ] Array configurable de objetos buenos (puntos, monedas, buffs).
  - [ ] Array configurable de objetos malos (bombas, penalizadores).
  - [ ] Ajuste independiente de velocidades de caída y escalas/tamaños de colisión.

## 🟡 Feature: Feedback de Loot y Cofres (Mensajes de Diálogo No Invasivos)
- [ ] **Sistema de Toast / Notificación Breve:**
  - [ ] Notificación visual no intrusiva y de corta duración (ej. popup superior/inferior flotante que desaparece solo en 1.5s).
  - [ ] Icono del ítem + nombre + cantidad (ej. "+3 Poción Azul", "+1 Llave Oxidada").
  - [ ] Disparo automático al recolectar drops de enemigos (`PickupItem`).
  - [ ] Integración en cofres (`chest.gd`) al abrirlos, reemplazando diálogos bloqueantes por toasts ligeros.

---

## 🎯 Próximo Gran Hito: Vertical Slice
- [ ] Integración de un bucle de juego completo:
  - Exploración en Overworld ➔ Desbloqueo de puertas con llaves ➔ Combate/Loot de enemigos con notificaciones.
  - Acceso interactivo a los minijuegos pulidos temáticamente.
  - Retorno con recompensas añadidas al inventario global para progresión en el mapa.


