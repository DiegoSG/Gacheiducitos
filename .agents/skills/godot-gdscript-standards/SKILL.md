---
name: godot-gdscript-standards
description: Guía y estándares de código GDScript para Godot 4.6 (tipado fuerte, convenciones, optimización y modularidad).
---

# Skill: Estándares de GDScript (Godot 4.6)

Guía de referencia de código para la escritura de scripts en este proyecto.

## 1. Tipado Fuerte (Static Typing)
Usa tipado explícito siempre que sea posible para evitar bugs en runtime y mejorar el rendimiento de Godot:

```gdscript
# Correcto
@export var speed: float = 200.0
var target_position: Vector2 = Vector2.ZERO

func move_to(target: Vector2) -> void:
    target_position = target
```

## 2. Inyección y Nodos (`@onready` y `@export`)
- Prefiere `@export` para variables configurables desde el Inspector de Godot.
- Usa `@onready` para obtener referencias a nodos hijos.

```gdscript
@export var health_component: Node
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
```

## 3. Señales y Desacoplamiento
- Los nodos hijos emiten señales hacia arriba (hacia los padres).
- Los nodos padres llaman métodos hacia abajo (hacia los hijos).
- Conecta señales mediante código si las instancias se crean dinámicamente:
  `button.pressed.connect(_on_button_pressed)`

## 4. Convenciones de Nombres
- **Variables/Funciones:** `snake_case` (`func update_health() -> void:`)
- **Constantes:** `UPPER_SNAKE_CASE` (`const MAX_HEALTH: int = 100`)
- **Señales:** `snake_case` (`signal health_changed(new_health: int)`)
- **Clases (`class_name`):** `PascalCase` (`class_name HealthComponent extends Node`)
