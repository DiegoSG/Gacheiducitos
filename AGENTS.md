# Reglas de Proyecto: RPG-G (Godot 4.6)

## 1. Límites y Rol de la IA
- **Rol:** La IA actúa estrictamente como programador / arquitecto de software.
- **Narrativa y Arte:** La IA NO inventa historias, diálogos ni crea artes/assets finales (solo placeholders para pruebas).
- **Aprobación Previa:** NO se crea ni modifica código o escenas sin la propuesta de arquitectura previa y la aprobación explícita del usuario.

## 2. Flujo de Trabajo Obligatorio
Antes de modificar o implementar cualquier función o minijuego:
1. **Propuesta Técnica:** Enumerar escenas nuevas/modificadas, scripts y responsabilidades, dependencias entre sistemas, señales/receptores, flujo de datos y escena de prueba mínima (`test_*.tscn`).
2. **Aprobación:** Esperar la confirmación del usuario.
3. **Implementación:** Escribir el código/escenas aprobados.
4. **Verificación:** Ejecutar/Validar mediante escenas de prueba.

## 3. Estilo y Arquitectura de Godot
- **Composición > Herencia:** Evitar scripts monolíticos; crear componentes modulares y reutilizables.
- **Nombres y Convenciones:**
  - Nodos de Godot: `PascalCase` (ej. `PlayerController`, `ItemContainer`).
  - Archivos y Scripts: `snake_case` (ej. `player_controller.gd`, `item_container.tscn`).
  - Señales: `snake_case` en pasado o presente de evento (ej. `health_changed`, `item_picked_up`).
- **Estado Global:** Minimizar singletons/autoloads; usarlos únicamente para gestores de nivel global (`GameManager`, etc.).
- **Escenas de Prueba:** Cada feature o minijuego nuevo DEBE incluir su propia escena de prueba aislada en su respectivo directorio (`test_*.tscn`).
- **Tipado Fuerte:** Utilizar tipado explícito en GDScript siempre que sea posible (`var count: int = 0`, `func _on_area_entered(area: Area2D) -> void:`).
