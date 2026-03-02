# Hoja de Ruta del Proyecto (Roadmap)

## Fase 1: Prototipo (Actual)
- [x] Movimiento Básico del Jugador
- [x] Sistema de Interacción
- [x] Transición a Minijuegos
- [ ] Primer Minijuego Jugable

*Nota:* ya existe un `GameManager` y entrada para pruebas de minijuegos.

## Fase 2: Bucle Principal
1. **Base Overworld**
   - [x] Movimiento, cámara, interacción (completado).
   - [ ] Inventario básico y UI asociada.
   - [ ] Primer NPC con misión simple.

2. **Progresión y Misiones**
   - [ ] Definir estructura de misiones y estado.
   - [ ] Guardado/recuperado de progreso básico.
   - [ ] Agregar recolección de ítems al overworld.

3. **Minijuegos Iniciales**
   - [ ] Desarrollar minijuego Excavación con generador procedural y loot.
   - [ ] Crear puente de inventario entre minijuego y overworld.
   - [ ] Scene tests independientes para cada minijuego.

## Fase 3: Expansión de Contenido
- [ ] Añadir más NPCs y diálogos ramificados.
- [ ] Sistema de combate y enemigos básicos.
- [ ] Implementar minijuego Laberinto y Ritmo.
- [ ] Mejora de progresión: niveles, estadísticas, equipo.
- [ ] Desbloqueo de áreas y mapa.
- [ ] Integrar sonido y música.

## Fase 4: Pulido y Lanzamiento
- [ ] Corrección de errores y optimización.
- [ ] Pulido de UI/UX y efectos.
- [ ] Tests automáticos y CI funcional.
- [ ] Exportar builds para plataformas objetivo.
