---
name: godot-inventory-item-system
description: Estandarización para crear ítems, gestionar inventario, estadísticas de jugador y verificación de consistencia en RPG-G.
---

# Skill: Sistema de Ítems e Inventario (RPG-G)

Esta habilidad se activa al registrar nuevos ítems, diseñar tablas de loot, ajustar estadísticas de jugador o interactuar con el inventario global.

---

## 1. Arquitectura de Ítems e Inventario
- **`ItemDatabase` (Autoload):** Diccionario central con la definición, metadatos y texturas/iconos de todos los ítems.
- **`Inventory` (Autoload):** Administra los stacks, cantidades, añadir/remover objetos y emitir señales de cambio (`inventory_updated`).
- **`PlayerStats` (Autoload):** Maneja atributos (salud, energía, monedas) y sincronización con ítems consumibles o equipables.

---

## 2. Convenciones de Identificadores (Item ID)
- Identificadores en `snake_case` y únicos (ej. `wooden_sword`, `healing_herb`, `ancient_coin`).
- Las descripciones y nombres visibles deben estar centralizados en los recursos de datos (`res://data/...`).

---

## 3. Scripts de Utilidad y Verificación
- Usar `res://src/core/utils/verify_items.gd` para verificar que no existan IDs duplicados o recursos de iconos rotos.
- Usar `res://src/core/tools/generate_items.gd` para generación por lotes de recursos de ítems si aplica.
