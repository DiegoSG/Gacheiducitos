---
name: godot-project-structure
description: Estándares de arquitectura de directorios, organización limpia de archivos, convenciones de nombres y reglas anti-caos para RPG-G (Godot 4.6).
---

# Skill: Estructura del Proyecto y Organización de Archivos (RPG-G)

Esta habilidad establece la taxonomía estricta de carpetas, convenciones de nombrado e higiene del repositorio para mantener el proyecto 100% ordenado, escalable y predecible.

---

## 1. Árbol de Directorios Estándar

```text
Gacheiducitos/
├── .agents/                      # Skills y configuración de agentes IA
│   └── skills/
├── design/                       # Documentación de diseño, GDD y especificaciones
│   ├── mockups/                  # Archivos Krita (.kra) e imágenes de referencia artística
│   ├── Feature_Checklist.md      # Checklist oficial de hitos y tareas
│   └── ... (documentación técnica y narrativa)
├── DialogueApp/                  # Herramienta visual web (Node/Express) para editar archivos .dialogue
├── rpg-g/                        # Raíz del proyecto Godot (contiene project.godot)
│   ├── .godot/                   # Caché e importaciones internas (ignorado en Git)
│   ├── addons/                   # Plugins externos (Dialogue Manager, etc.)
│   ├── assets/                   # Recursos visuales y sonoros estáticos
│   │   ├── items/
│   │   │   └── icons/            # Texturas PNG de iconos de ítems (sin scripts)
│   │   └── sprites/              # Tilesets, texturas de props, puertas, etc.
│   ├── data/                     # Recursos nativos del motor (.tres) y definiciones
│   │   ├── items/                # Instancias de recursos de ítems individuales (.tres)
│   │   └── resource_types/       # Scripts GDScript que definen Custom Resources (ItemData)
│   ├── src/                      # Código fuente y escenas del juego
│   │   ├── core/                 # Infraestructura base y autoloads (GameManager, Inventory, SaveSystem...)
│   │   │   ├── components/       # Componentes reutilizables (Hitbox, Hurtbox, HitEffect, LootDropComponent)
│   │   │   ├── data/             # Datos generados (narrative_defaults.gd, lo escribe DialogueApp)
│   │   │   ├── pipeline/         # Sistema de eventos (GameTrigger, ActionRunner, OnEventListener, ActionResource)
│   │   │   │   └── actions/      # Acciones modulares (MinigameAction, DoorAction, etc.)
│   │   │   ├── tests/            # Test runners automatizados (scripts SceneTree)
│   │   │   ├── utils/            # Utilidades (PersistenceIdHelper, verify_items)
│   │   │   └── collision_layers.gd # Constantes de capas de física (CollisionLayers)
│   │   ├── minigames/            # Minijuegos desacoplados
│   │   │   ├── minigame_base.gd  # Clase base (recompensas, pantalla de resultado, helpers de pool/iconos)
│   │   │   ├── mg_catcher/       # Minijuego de atrapar objetos
│   │   │   ├── mg_excavation/    # Minijuego de excavación
│   │   │   ├── mg_runner/        # Minijuego runner
│   │   │   ├── mg_smasher/       # Minijuego smasher
│   │   │   ├── mg_trampolin/     # Minijuego de trampolín
│   │   │   └── tests/            # Mocks, escenas de prueba y menús de depuración config_mg_*
│   │   ├── overworld/            # Todo lo perteneciente al mundo abierto
│   │   │   ├── components/       # Componentes de nivel (cámara, portales, spawns, bordes, LevelExceptionConfig)
│   │   │   ├── enemies/          # Enemigos del overworld (GenericEnemy)
│   │   │   ├── interactables/    # Props interactivos (cofres, placas, interruptores, pickups, minijuegos)
│   │   │   ├── levels/           # Niveles (level_XX.tscn) y plantillas
│   │   │   ├── npcs/             # NPCs, dummies y sus diálogos
│   │   │   └── player/           # Controlador y escena del jugador (incluye el HUD)
│   │   └── ui/                   # Interfaces de usuario
│   │       ├── balloon/          # Globo de diálogo (configurado como balloon_path del Dialogue Manager)
│   │       ├── inventory/        # Interfaz de inventario
│   │       ├── loot_feedback/    # HUD (player_hud.tscn) y toasts de botín
│   │       ├── save/             # Menú y slots de guardado
│   │       └── screen_fader.*    # Transiciones de pantalla con fade
│   └── tools/                    # (crear solo cuando haga falta) Herramientas externas bash/python
│       └── asset_tools/
```

---

## 2. Convenciones Estrictas de Nombrado

1. **Archivos y Carpetas:**
   - **Siempre en `snake_case`:** `player.gd`, `pickup_item.tscn`, `hud.tscn`, `inventory_ui.tscn`.
   - **Prohibido:** Nombres con mayúsculas en archivos (`PickupItem.tscn`, `HUD.tscn`, `InventoryUI.tscn` están prohibidos).
2. **Nodos de Escena (Scene Tree):**
   - **Siempre en `PascalCase`:** `PlayerController`, `InteractionArea`, `HitboxComponent`.
3. **Prefijos y Sufijos de Features:**
   - Minijuegos: prefijo `mg_<nombre>` para carpetas y escenas principales (`mg_catcher_game.tscn`).
   - Escenas de prueba aisladas: prefijo `test_*.tscn` (ej. `test_minigame_flow.tscn`).
   - Runners automatizados: sufijo `*_runner.gd` en `src/core/tests/`.

---

## 3. Reglas de Higiene y Limpieza (Anti-Basura)

- **Cero archivos temporales:** NUNCA dejar en el repositorio archivos de respaldo del editor (`*~`, `*.swp`, `*.bak`, `*.tmp`) ni autosaves de programas de arte (`.*-autosave.*`).
- **Separación de responsabilidades:**
  - Las carpetas en `assets/` solo contienen texturas, fuentes y audio. Ningún script ni herramienta debe residir dentro de `assets/`.
  - Las herramientas externas (Python, Bash, ImageMagick) residen en `rpg-g/tools/asset_tools/`.
- **Cero carpetas duplicadas o anidadas redundantemente:** No crear carpetas como `design/Design/`, `minigames/minigames/`, etc.
- **Cero sistemas paralelos:** Si una funcionalidad ya la resuelve un sistema core (ej. `GameTrigger` + `MinigameAction`), está terminantemente prohibido crear scripts aislados redundantes (`minigame_trigger.gd`).

---

## 4. Dónde Guardar Cada Cosa (Guía Rápida)

| Tipo de Elemento | Carpeta Obligatoria |
| :--- | :--- |
| Ítem nuevo (`.tres`) | `rpg-g/data/items/` |
| Textura / Icono nuevo (`.png`) | `rpg-g/assets/items/icons/` |
| Sprite de entorno / Tileset | `rpg-g/assets/sprites/` |
| Nuevo Minijuego | `rpg-g/src/minigames/mg_<nombre>/` |
| Nueva Acción del Pipeline | `rpg-g/src/core/pipeline/actions/` |
| Nuevo Nivel / Escena de juego | `rpg-g/src/overworld/levels/` |
| Nuevo Interactuable del Mundo | `rpg-g/src/overworld/interactables/` |
| Nuevo Componente reutilizable / de Combate | `rpg-g/src/core/components/` |
| Nuevo Enemigo del overworld | `rpg-g/src/overworld/enemies/` |
| Nueva Pantalla / Menú UI | `rpg-g/src/ui/<nombre>/` |
| Documento o Mockup de Diseño | `design/` o `design/mockups/` |
| Test Runner automatizado | `rpg-g/src/core/tests/` |
| Editor visual de diálogos | `DialogueApp/` |
| Persistencia del mundo (Autoload) | `rpg-g/src/core/world_state_manager.gd` |

