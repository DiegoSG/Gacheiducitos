# Hoja de Ruta del Proyecto (Roadmap)

**Estado actual: 2026-10-05** | **Próximo hito: Fase 2.5 - Primer Test Jugable**

---

## ✅ Fase 1: Prototipo (Completada)
- [x] Movimiento Básico del Jugador
- [x] Sistema de Interacción
- [x] Transición a Minijuegos
- [x] Primer Minijuego Jugable (Supaplex + Laberinto)

## 🔄 Fase 2: Bucle Principal (En Progreso)

### 2.1 - Mundo Exterior y Controles (Completado)
- [x] Overworld funcional
- [x] Controles mejorados (rama `JoystickAndControls`, PR #4)
- [x] Sistema de Menús
- [x] Integración con Minijuegos

### 2.2 - Sistema de Audio y Niveles (Completado - 2026-10-05)
- [x] Sistema de audio avanzado (229 eventos conectados)
- [x] Level app - Editor de niveles con generador automático de escenas
- [x] Sistema de Diálogos (Dialogue Manager 3.10.5)

### 2.3 - Sistema de NPCs y Narrativa (Completado)
- [x] NPCs funcionales con diálogo
- [x] Sistema de eventos y scripts

### 2.4 - Escudo Simple (🚧 **CRÍTICO - EN PROGRESO**)
- [ ] **Efecto visual de escudo** - mostrar zona protegida
- [ ] **Protección sin daño** - no recibir daño cuando está activo
- [ ] **Sin movimiento activo** - no poder moverse mientras usa escudo

### 2.5 - Primer Test Jugable (🎯 **SIGUIENTE HITO - 2 TAREAS CRÍTICAS**)
- [ ] **Plantilla de nivel funcional** (depende: ✓ level app + fix Dummies → npc_barnaby.tscn)
- [ ] **2 Niveles conectados en overworld** (depende: plantilla 2.4 + ✓ level app)
- [ ] Flujo completo: overworld → nivel → interacción simple

### 2.6 - Sistema de Armas y Equipamiento (📋 **Roadmap Futuro**)
- [ ] Sistema de equipamiento (armas y escudos equipados)
- [ ] Slots rápidos para armas
- [ ] Switch entre armas/escudos
- [ ] Game Over y victoria (como nivel especial)

---

## 📋 Fase 3: Expansión de Contenido
- [ ] Sistema de Inventario
- [ ] Más niveles y variedad de enemigos
- [ ] Pulido de arte y efectos visuales

## 🎮 Fase 4: Pulido y Lanzamiento
- [ ] Corrección de Errores
- [ ] Pulido de UI/UX
- [ ] Exportar Builds

---

## 📊 Dependencias Críticas para 2.5

```
level app (✓) + fix Dummies → npc_barnaby.tscn
    ↓
plantilla de nivel + escudo simple (⚠️)
    ↓
2 niveles conectados (⚠️)
    ↓
✓ Primer Test Jugable
```

**Lo que desbloquea el audio:** Toda ambientación sonora ya está lista; sólo hace falta llenar niveles con efectos.

**Lo que desbloquea el level app:** Construcción rápida de niveles (solo falta fix del asset Dummies).

**Escudo simple para 2.5:** Efecto visual + protección + sin movimiento. El sistema de armas completo (equipamiento, slots, switch) va en 2.6.
