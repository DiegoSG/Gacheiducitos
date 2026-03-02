# Gacheiducitos

Proyecto RPG-G en Godot.

## Configuración inicial
1. Abrir `rpg-g/project.godot` en Godot 3/4.
2. Añadir `res://scripts/managers/Inventory.gd` como *Autoload* (singleton) y nombrarlo `InventoryManager` (u otro identificador válido).
3. Opcional: cargar escena `res://scenes/tests/inventory_test.tscn` para probar el inventario/quest. Usa `ui_accept` para interactuar, `ui_cancel` para botar un ítem al piso.

## Flujo de trabajo
- `develop` contiene cambios en curso.
- Crear ramas `feature/*` para nuevas funcionalidades.
- Usar `Feature_Checklist.md` y `Roadmap.md` para seguimiento.

