# Plan para resolver los pendientes

**Fecha:** 13 de Octubre, 2026 · base: `design/Roadmap.md`

Las tareas van en tandas, de la más simple a la más grande. Cada tanda empieza con una propuesta técnica corta (regla del proyecto) y, una vez aprobada, se implementa, se prueba con su `test_*.tscn` y se commitea. Etiquetas: **Solo** = Claude puede hacerla sin que Diego tenga que decidir ni probar nada a mano; **Revisa** = Diego tiene que probar en Godot o elegir algo; **Diseño** = antes hay que decidir cómo debe ser.

## Tanda 1 — Simples y autónomas (Solo) · ✅ hecha el 13 Oct

| # | Tarea | Qué se hace | Archivos |
|---|---|---|---|
| 1.1 | Antídoto real | Copiar el efecto `CureStatusEffect` de `test_antidote.tres` a `antidote.tres` (hoy el real no tiene efectos, solo la descripción). | `data/items/antidote.tres` |
| 1.2 | Sonidos dobles | Quitar el segundo sonido en los pares que suenan en el mismo frame (`sfx_player_invulnerable` tras `hurt`, `sfx_enemy_stunned` tras `enemy_hurt`). | `player.gd`, `generic_enemy.gd` |
| 1.3 | `pitch_random` en audio | Campo nuevo en `AudioEntry` (por defecto 0, sin cambio de comportamiento) y aplicarlo en `play_sfx`. | `audio_entry.gd`, `audio_manager.gd` |
| 1.4 | Cooldown anti-spam | Campo `cooldown` en `AudioEntry` (por defecto 0) y un diccionario de último uso por ID en `AudioManager`. | mismos |
| 1.5 | Backup `.bak` | Antes de sobrescribir un slot, copiar el archivo anterior a `.bak`; al cargar, si el principal está corrupto, usar el `.bak`. | `src/core/save_system.gd` |
| 1.6 | Limpieza de PRs | Cerrar los borradores #5, #8, #13 y #14 (su contenido ya está en `FirstPlayableTest` o quedó obsoleto). Lo hago solo con tu OK. | GitHub |

## Tanda 2 — Pequeñas, con prueba en Godot (Revisa) · ✅ hecha el 13 Oct

| # | Tarea | Qué se hace |
|---|---|---|
| 2.1 | Golpe bloqueado (P1) | Mover el sonido del golpe de `HitboxComponent._apply_hit` al receptor, que elige `hurt` / `block_hit` / nada según el resultado. Nuevo ID `sfx_player_block_hit` en el catálogo (necesita un archivo; uso un proxy). |
| 2.2 | Animación de salida de portal | En `game_manager.gd:209`, colocar al jugador en el portal y moverlo con un tween corto hasta el arrival point, con el input bloqueado mientras dura. |
| 2.3 | IDs de audio nuevos | `sfx_enemy_attack_windup` al iniciar el ataque, `sfx_player_low_health` al bajar de un umbral. Proxies hasta tener archivos. |
| 2.4 | Sonido posicional | `AudioManager.play_sfx_at(id, pos)` con pool de `AudioStreamPlayer2D`; usarlo en enemigos y objetos del mundo. |
| 2.5 | Borrar ítems `test_*` | Solo si `test_status_effects.tscn` deja de usarlos o se mueven a una carpeta de tests. |

## Tanda 3 — Necesitan una decisión tuya (Diseño)

| # | Tarea | Qué falta decidir |
|---|---|---|
| 3.1 | Menú de opciones | Qué va además del volumen (pantalla completa, vibración, idioma, controles). |
| 3.2 | Diseño del HUD | Lugar fijo de cada elemento; conviene antes que el HUD de equipamiento. |
| 3.3 | Ambiente por nivel (`amb_level_XX`) | Qué sonido lleva cada nivel. |
| 3.4 | Runner con D-Pad lateral | Si se agrega o no. |

## Tanda 4 — Fase 2.6, combate (grandes, una propuesta cada una)

Orden por dependencias: **Equipamiento** (2 slots de arma + escudo, `Sistema_Armas_y_Escudo.md`) → **Escudo completo** (`ShieldData`, ángulo, porcentaje) → **Efecto real de los 4 slots** → **HUD de equipamiento** (después de 3.2) → **Cambio rápido de armas y hotbar**.

## Tanda 5 — Contenido y más adelante

Game Over / Victoria como nivel, registro de misiones y POIs en el mapa, misiones de minijuegos, sistema de energía, temas visuales y mejoras por minijuego, controles táctiles, tests headless, builds. Se planifican cuando termine la Fase 2.6.

## Cómo seguimos

1. Apruebas la Tanda 1 (o quitas lo que no quieras).
2. La implemento en tu PC en una rama, con un commit por tarea, y marco cada una en `Roadmap.md`.
3. Te paso la Tanda 2 con las pruebas que tienes que hacer en Godot.
