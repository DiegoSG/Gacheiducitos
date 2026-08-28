---
name: project-rules
description: Reglas de proyecto, límites de rol de IA, flujo de trabajo obligatorio (propuesta técnica previa, aprobación, implementación y testing) y directrices de arquitectura para RPG-G.
---

# Skill: Reglas del Proyecto (RPG-G)

Esta habilidad establece los límites de interacción, el rol de la IA y el flujo de trabajo estricto de desarrollo para el proyecto **RPG-G (Godot 4.6)** basado en `design/Rules_of_Engagement.md` y `AGENTS.md`.

---

## 1. Límites y Rol de la IA
- **Rol Técnico:** La IA actúa estrictamente como programador / arquitecto de software.
- **Narrativa y Arte:** La IA **NO** inventa tramas, lore, diálogos ni crea assets finales (solo placeholders/mockups para pruebas técnicas). El usuario es el único autor creativo.
- **Aprobación Previa Obligatoria:** **NO** se crea ni modifica código, escenas o recursos sin antes presentar una propuesta técnica formal y recibir la aprobación explícita del usuario.

---

## 2. Flujo de Trabajo en 5 Pasos
Para cualquier nueva mecánica, refactorización, minijuego o corrección:

1. **Requerimiento / Especificación:** El usuario define la mecánica o necesidad técnica.
2. **Propuesta Técnica Formal:** La IA elabora una propuesta estructurada utilizando la skill `godot-architecture-proposal`, detallando:
   - Resumen técnico.
   - Escenas y estructura de nodos (`*.tscn`).
   - Scripts y responsabilidades (`*.gd`).
   - Señales y flujo de datos.
   - Escena de prueba mínima (`test_*.tscn`).
3. **Aprobación Explícita:** Esperar la confirmación/visto bueno del usuario.
4. **Implementación:** Escribir el código y escenas acordadas siguiendo `godot-gdscript-standards`.
5. **Validación:** Validar el funcionamiento en la escena de prueba (`test_*.tscn`) y actualizar los checks en `design/Feature_Checklist.md`.

---

## 3. Principios de Arquitectura en Godot 4.6
- **Composición sobre Herencia:** Evitar scripts monolíticos; crear componentes modulares y reutilizables.
- **Minimizar Singletons (Autoloads):** Reservados exclusivamente para gestores globales reales (`GameManager`, `Inventory`, `ItemDatabase`, `PlayerStats`, `NarrativeManager`, `DialogueManager`).
- **Aislamiento:** Los sistemas y minijuegos deben poder ejecutarse de forma independiente sin depender rígidamente del mapa principal.
- **Escenas de Prueba:** Cada funcionalidad o minijuego DEBE incluir su propia escena de prueba (`test_*.tscn`) en su respectivo directorio.

---

## 4. Convenciones de Nombres
- **Nodos en Godot:** `PascalCase` (ej. `PlayerController`, `InteractionArea`).
- **Archivos y Directorios:** `snake_case` (ej. `player_controller.gd`, `stone_spawner.tscn`).
- **Funciones y Variables:** `snake_case` con tipado estático (ej. `func calculate_damage(amount: int) -> int:`).
- **Constantes:** `UPPER_SNAKE_CASE` (ej. `const MAX_INVENTORY_SLOTS: int = 20`).
- **Señales:** `snake_case` en tiempo pasado o descriptivo (ej. `item_collected`, `health_changed`).
