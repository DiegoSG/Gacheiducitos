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


## 🟡 Feature: Minijuego A (Excavación)
- [x] Generador Procedimental (Autómatas Celulares) (Ref: `Minijuego_Supaplex.md`)
- [x] Algoritmo de Validación de Conectividad (Flood Fill) (Ref: `Minijuego_Supaplex.md`)
- [ ] Reglas de "Riesgo vs Recompensa" (Colocación de items) (Ref: `Minijuego_Supaplex.md`)
- [ ] Perfiles de Nivel (Variación de densidades) (Ref: `Minijuego_Supaplex.md`)
- [x] Motor de Grid y Lógica de Excavación (Ref: `Minijuego_Supaplex.md`)
- [x] Gravedad de Piedras (Caída y Deslizamiento) (Ref: `Minijuego_Supaplex.md`)
- [ ] Sistema de Misión (Contador de Raíces / Rescate de NPC) (Ref: `Minijuego_Supaplex.md`)
- [ ] Generador de Loot (Monedas, Corazones) (Ref: `Minijuego_Supaplex.md`)
- [ ] Sistema de Bombas (Colocación y cuenta atrás) (Ref: `Minijuego_Supaplex.md`)
- [ ] Lógica de Explosión 3x3 (Detección de tiles destructibles) (Ref: `Minijuego_Supaplex.md`)
- [ ] Tipos de Muro (Irrompible vs Rompible) (Ref: `Minijuego_Supaplex.md`)
- [ ] IA de Enemigo (Ciego/Sonido) (Ref: `Minijuego_Supaplex.md`)
- [ ] Lógica de Radio de Ruido (Excavación vs Bomba) (Ref: `Minijuego_Supaplex.md`)
- [ ] Sistema de Sigilo en Túneles Vacíos (Ref: `Minijuego_Supaplex.md`)
- [ ] Sistema de Semilla Persistente (Mismo nivel al reintentar) (Ref: `Minijuego_Supaplex.md`)
- [ ] Temporizador de Nivel y Gestión de Vidas (Ref: `Minijuego_Supaplex.md`)
- [ ] Mecánica de Trampas de Bloqueo (One-way) (Ref: `Minijuego_Supaplex.md`)
- [ ] Condición de Salida (Activación de puerta tras objetivo) (Ref: `Minijuego_Supaplex.md`)
- [ ] Puente de Inventario (Transferencia de items al Overworld) (Ref: `Minijuego_Supaplex.md`)

## 🟡 Feature: Minijuego B (Laberinto)
- [ ] Shader de Niebla de Guerra / Sistema de Iluminación (Ref: `Minijuego_Laberinto.md`)
- [ ] Generación de laberinto y cambio de muros fuera de cámara (Ref: `Minijuego_Laberinto.md`)
- [ ] Sistema de recolección de objetos clave (Ref: `Minijuego_Laberinto.md`)
- [ ] Lógica de "Bucle Espacial" (Screen Wraparound) (Ref: `Minijuego_Laberinto.md`)
- [ ] IA de Enemigos (Drenado de luz) (Ref: `Minijuego_Laberinto.md`)

## 🟡 Feature: Minijuego C (Ritmo)
- [ ] Metrónomo sincronizado (AudioServer BPM) (Ref: `Minijuego_Ritmo.md`)
- [ ] Buffer de entrada y validación de timing (Ref: `Minijuego_Ritmo.md`)
- [ ] Validador de secuencias de comandos (Símbolos/Inputs) (Ref: `Minijuego_Ritmo.md`)
- [ ] Máquina de estados de multiplicadores/power-ups (Ref: `Minijuego_Ritmo.md`)
- [ ] Feedback visual de pulso y comandos (Ref: `Minijuego_Ritmo.md`)
