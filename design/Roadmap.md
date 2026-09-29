# Hoja de Ruta del Proyecto (Roadmap)

## Fase 1: Prototipo (Completado)
- [x] Movimiento Básico del Jugador (Grilla 60x60, colisiones y cámara)
- [x] Sistema de Interacción (Actionable, Cofres, Puertas, Portales, Palancas y Placas)
- [x] Sistema de Eventos y Triggers (GameTrigger, DoorAction, DestroyNodeAction)
- [x] Sistema de Enemigos en Overworld (Patrullas, detección, persecución y LootDropComponent)
- [x] Sistema de Inventario Base y UI conectada

## Fase 2: Minijuegos y Bucle Principal (Completado)
- [x] Base de Minijuegos existentes (Excavation, Catcher, Runner, Smasher, Trampolin)
- [x] Estandarización y ciclo de vida común (`MinigameBase` / `IMinigame`)
- [x] Sistema de victoria / derrota uniforme con UI desacoplada
- [x] Recolección de items/drops en minijuegos transferibles a `Inventory`
- [x] Triggers y señales de inicio desde el Overworld (`MinigameAction` / `GameTrigger`)
- [x] Retorno parametrizado al Overworld con nivel y spawn específico (reutilizando IDs de llegada de puertas/portales)
- [x] Herramientas de configuración y balance de minijuegos

## Fase 2.5: Primer Jugable de Test (Milestone Actual)
- [x] Limpieza integral del código (bugs, sistemas duplicados, tipado, código muerto) — 29 Sep 2026
- [x] Variables unificadas (`GameVariables`, condiciones, `VariableWatcher`) integradas con DialogueApp
- [x] Estados alterados (`StatusEffectData`) y efectos de ítems combinables
- [x] Texto de puerta cerrada y pausa del juego durante diálogos
- [ ] Sistema de armas: cambio y mejora de armas
- [ ] Escudo
- [ ] Remapeo estándar de controles y soporte completo de joystick
- [ ] Menú principal y menú de pausa
- [ ] Flujo de Game Over
- [ ] Plantilla de nivel (`template_level.tscn`) y 2 niveles interconectados del Vertical Slice
- [ ] Audio básico (música y efectos)
- [ ] Animación de salida de portal

## Fase 3: Expansión de Contenido
- [ ] Añadir NPCs y Diálogo avanzado (`DialogueManager`)
- [ ] Mazmorras y nuevos niveles interconectados
- [ ] Implementación de Sonido y Música

## Fase 4: Pulido y Lanzamiento
- [ ] Corrección de Errores y pruebas de integración
- [ ] Pulido de UI/UX
- [ ] Exportar Builds (Desktop / Mobile)

## Backlog y Mejoras (TODO)
- [ ] **Controles de Minijuegos en Móviles:** Pruebas en Android para controles táctiles en minijuegos.
- [ ] **Sistema de energía:** diseñado en `Sistema_Checkpoints_y_Guardado.md`, no implementado (la Poción Azul lo menciona).
- [ ] **Registro de misiones visible:** `QuestAction` existe pero no hay UI de misiones.
- [ ] **Backup `.bak` de partidas guardadas.**
- [ ] **Scripts de test headless:** los runners de `src/core/tests/` no corren con `--script` (decisión: QA manual).
- [ ] **DialogueApp:** nodos que mezclan texto y `do` pierden la mutación; switch con operadores distintos de `==`.

