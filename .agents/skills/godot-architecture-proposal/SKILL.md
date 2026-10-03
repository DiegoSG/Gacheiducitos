---
name: godot-architecture-proposal
description: Genera una propuesta formal de arquitectura de escena y script para Godot 4.6 siguiendo las Rules of Engagement del proyecto antes de escribir código.
---

# Skill: Propuesta de Arquitectura Godot

Esta habilidad se activa al diseñar o planificar una nueva mecánica, minijuego o refactorización en el proyecto Godot.

## Plantilla de Propuesta

Al proponer una feature, genera la respuesta estructurada con las siguientes secciones:

### 1. Resumen de la Funcionalidad
Breve explicación técnica de la mecánica a implementar.

### 2. Escenas y Nodos (`*.tscn`)
- **Nombre de Escena:** `res://src/.../nombre_escena.tscn`
- **Estructura de Nodos:**
  ```text
  NodoRaiz (TipoNodo)
  ├── ComponenteA (TipoNodo)
  └── ComponenteB (TipoNodo)
  ```

### 3. Scripts y Responsabilidades (`*.gd`)
- `script_name.gd`: Responsable de [X] funcionalidad.
  - `@export` propiedades expuestas.
  - Métodos principales (`_ready`, `_process`, etc.).

### 4. Señales y Flujo de Datos
- **Señales Emitidas:** `signal_name(arg: Type)` -> Emitida cuando...
- **Conexiones / Receptores:** `NodoEmisor.signal -> NodoReceptor._on_signal`

### 5. Escena de Prueba (`test_*.tscn`)
- Ruta y estrategia para probar esta feature de manera aislada del resto del juego.

---
*Esperar aprobación del usuario antes de proceder a la implementación.*
