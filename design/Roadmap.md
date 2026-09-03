# Hoja de Ruta del Proyecto (Roadmap)

## Fase 1: Prototipo (Completado)
- [x] Movimiento Básico del Jugador (Grilla 60x60, colisiones y cámara)
- [x] Sistema de Interacción (Actionable, Cofres, Puertas, Portales, Palancas y Placas)
- [x] Sistema de Eventos y Triggers (GameTrigger, DoorAction, DestroyNodeAction)
- [x] Sistema de Enemigos en Overworld (Patrullas, detección, persecución y LootDropComponent)
- [x] Sistema de Inventario Base y UI conectada

## Fase 2: Minijuegos y Bucle Principal (Milestone Actual)
- [x] Base de Minijuegos existentes (Excavation, Catcher, Runner, Smasher, Trampolin)
- [ ] Estandarización y ciclo de vida común (`MinigameBase` / `IMinigame`)
- [ ] Sistema de victoria / derrota uniforme con UI desacoplada
- [ ] Recolección de items/drops en minijuegos transferibles a `Inventory`
- [ ] Triggers y señales de inicio desde el Overworld (`MinigameAction` / `GameTrigger`)
- [ ] Retorno parametrizado al Overworld con nivel y spawn específico (reutilizando IDs de llegada de puertas/portales)
- [ ] Herramientas de configuración y balance de minijuegos

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
- [ ] **Animación de salida de portal:** Desplazamiento desde el portal hacia el punto de spawn.

