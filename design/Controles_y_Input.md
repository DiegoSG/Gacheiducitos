# Especificación: Mapa de Controles Estándar y Soporte de Joystick

**Fecha:** 29 de Septiembre, 2026
**Proyecto:** RPG-G (Godot 4.6)
**Estado:** Diseño aprobado — pendiente de implementación (sin código)

---

## 1. Problema Actual

- El juego usa las acciones de menú de Godot (`ui_accept`, `ui_left`, ...) también para jugar: Espacio/E interactúan y a la vez confirman en menús.
- Los minijuegos dependen de esas mismas acciones (`ui_accept`, `ui_up`, `ui_down`).
- No existen acciones para escudo, arrojadiza, cambio de arma ni pausa.

## 2. Principio

- **Acciones de juego propias** (`move_*`, `interact`, `attack`, ...) para el gameplay.
- **Acciones `ui_*`** solo para navegar menús y UI.
- Teclado, ratón y mando mapeados en cada acción.

## 3. Mapa Aprobado

| Acción (InputMap) | Teclado / Ratón | Mando Xbox | Mando PlayStation |
|---|---|---|---|
| `move_left/right/up/down` | WASD / Flechas | Stick izq. / Cruceta | Stick izq. / Cruceta |
| `interact` | E | A | ✕ |
| `attack` | J / Clic izquierdo | X | ▢ |
| `shield` (mantener) | K / Clic derecho | LT | L2 |
| `weapon_prev` / `weapon_next` (alternar arma activa) | Q / R · Rueda del ratón | LB / RB | L1 / R1 |
| `inventory` | I / Tab | Y | △ |
| `pause` | Esc | Start | Options |
| `jump` (minijuegos) | Espacio | A | ✕ |

Notas:
- `weapon_prev` / `weapon_next` alternan entre los 2 slots de arma. `attack` usa el arma activa (si es arrojadiza, lanza): no hay acción `throw` (ver `Sistema_Armas_y_Escudo.md`).
- Zona muerta del stick configurada (0.2).

## 4. Alcance de la Implementación

- `project.godot`: nuevas acciones con teclado, ratón y mando.
- `player.gd`, los 5 minijuegos, `inventory_ui.gd` y cualquier `GameTrigger` en modo INTERACT: pasar a las acciones nuevas.
- `input_hints.gd` (utilidad): detecta el último dispositivo usado (teclado o mando) para que los textos de ayuda muestren la tecla o el botón correcto.
- Escena de prueba: `rpg-g/src/core/tests/test_input_map.tscn` (muestra en pantalla cada acción al pulsarla y el dispositivo activo).

## 5. Fuera de Alcance (más adelante)

- Menú para que el jugador reasigne teclas (remapeo en juego).
- Controles táctiles para Android.
