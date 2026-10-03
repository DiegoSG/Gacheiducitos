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


## Controles y Joystick (esquema unificado)
Mapa completo por contexto y hardware en la hoja "Gacheiducitos - Mapa de Controles" (Drive). Principio: los inputs no cambian entre contextos, para que aprender a jugar sea simple.
Esquema de botones: abajo = Acción, izquierda = Secundario (atacar, disparar, avance rápido de diálogo), arriba = Inventario, derecha = Comodín (reservado; hace de Atrás en menús, por confirmar). Pausa = Start. Stick derecho libre: solo se usaría para los slots si el mando elegido no tiene flechas.

- [ ] **Separar acciones de gameplay de las `ui_*`:** `move_*`, `interact`, `attack`, `block`, `pause`, `inventory`, `slot_1..4`. Las `ui_*` quedan solo para menús.
- [ ] **Limpiar mapeos extra:** quitar Back (inventario) y LB (ataque) del InputMap; el D-Pad deja de mover en Overworld (sus 4 flechas son los slots) y el stick izquierdo queda como único movimiento. En minijuegos no hay slots y el D-Pad queda libre.
- [ ] **Teclado nuevo:** K ataca/dispara/avance rápido, L bloquea, Tab/I inventario, P pausa, Esc atrás, E/Espacio/Enter acción.
- [ ] **Bloqueo (`block`):** acción y comportamiento del jugador (LB/L1/L en mando).
- [ ] **4 slots de equipado rápido:** teclas 1-4 y D-Pad (↑ → ↓ ←). Sirven para cambiar arma, consumir poción y cambiar escudo.
- [ ] **Asignación de slots desde el inventario:** con el inventario abierto, las teclas 1-4 (D-Pad) asignan el ítem seleccionado. Solo armas, escudos y consumibles; no llaves ni ítems de quest.
- [ ] **Menús unificados (inicio, pausa y opciones):** mismo esquema de navegación en los tres; Start abre y cierra la pausa. La pausa de un minijuego incluye "Abandonar minijuego", que cuenta como perder (se pierden los ítems recogidos en esa partida).
- [ ] **Runner con mando:** A salta, X dispara, D-Pad abajo agacha. Evaluando desplazamiento lateral con D-Pad izquierda/derecha.
- [ ] **Pausa en minijuegos:** conectar `pause` en Runner, Catcher, Trampolín, Smasher y Excavación.
- [ ] **Diálogos:** el texto se escribe solo; Acción lo completa de golpe; Acción de nuevo pasa al siguiente; Avance rápido salta al final del diálogo o al próximo nodo de decisión.
- [ ] **Smasher con mando:** cursor movido con el stick izquierdo y Acción para golpear (hoy solo responde a click de mouse).
- [ ] **Debug F3:** pasar `KEY_F3` hardcodeado a una acción del InputMap.
- [ ] **Controles táctiles (Android):** joystick virtual y botones Acción, Secundario, Bloqueo, Mochila, Pausa y slots 1-4 (reemplaza el ítem de Backlog "Controles de Minijuegos en Móviles").
