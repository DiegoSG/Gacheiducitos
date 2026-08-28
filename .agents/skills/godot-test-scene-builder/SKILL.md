---
name: godot-test-scene-builder
description: Guía y estructura para crear escenas de prueba aisladas (test_*.tscn) y mocks mínimos para validar sistemas en Godot 4.6.
---

# Skill: Creador de Escenas de Prueba (`test_*.tscn`)

Esta habilidad se activa al preparar la validación de cualquier feature, script o minijuego nuevo en el proyecto.

---

## 1. Regla Fundamental
Ninguna funcionalidad se considera completada sin su respectiva escena de prueba aislada ubicada en el mismo módulo o en su carpeta de tests:
- `res://src/.../test_[nombre_feature].tscn`

---

## 2. Estructura Estándar de una Escena de Prueba
```text
TestRunner (Node2D o Control)
├── Environment / MockMap (TileMapLayer, StaticBody2D, etc.)
├── TargetComponent (El nodo/sistema bajo prueba)
├── TestUI / DebugOverlay (CanvasLayer con Labels/Buttons para forzar estados)
└── Camera2D (Opcional, para visualización adecuada)
```

---

## 3. Principios de Mocks y Dependencias
- Si el componente depende de un Autoload (`Inventory`, `NarrativeManager`, `GameManager`):
  - Verificar que el Autoload esté registrado en `project.godot` para que esté disponible automáticamente en el runner de pruebas.
  - Si se requieren datos específicos, inicializarlos en el `_ready()` del script de prueba.
- Añadir controles de teclado o botones debug en pantalla para simular inputs extremos (ej. spawn masivo, recibir daño, forzar victoria/derrota).
