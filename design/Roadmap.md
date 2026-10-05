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

### 2.4 - Sistema de Combate (🚧 **CRÍTICO - EN PROGRESO**)
- [ ] Sistema de armas básicas
- [ ] Sistema de escudo
- [ ] Daño y colisiones de combate
- [ ] Animaciones de ataque/defensa

### 2.5 - Primer Test Jugable (🎯 **SIGUIENTE HITO - 3 TAREAS CRÍTICAS**)
- [ ] **Plantilla de nivel funcional** (depende: ✓ level app)
- [ ] **2 Niveles conectados en overworld** (depende: ✓ level app + plantilla)
- [ ] **Sistema Game Over** (depende: combate 2.4)
- [ ] Flujo completo: overworld → nivel → combate → Game Over o victoria

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
overworld (✓) + nivel app (✓) 
    ↓
plantilla de nivel (⚠️)
    ↓
2 niveles conectados (⚠️)
    ↓
+ sistema combate (armas/escudo) (⚠️)
    ↓
Game Over (⚠️)
```

**Lo que desbloquea el audio:** Toda ambientación sonora ya está lista; sólo hace falta llenar niveles con efectos.

**Lo que desbloquea el level app:** Construcción rápida de niveles; eliminó el cuello de botella manual.
