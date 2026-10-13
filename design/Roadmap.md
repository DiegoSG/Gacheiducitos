# Hoja de Ruta del Proyecto (Roadmap)

**Actualizado:** 13 de Octubre, 2026 (con las marcas de Diego en el checklist) · rama `FirstPlayableTest`

Esta es la **única lista de tareas pendientes** del proyecto. Unifica lo que antes estaba repartido en este archivo, en `Feature_Checklist.md` (sección "Tareas Pendientes" y las features 🟡), en los `TODO` del código, en los docs de diseño (`Sistema_Armas_y_Escudo.md`, `Controles_y_Input.md`, `Capas_y_Orden_Z.md`, `Sistema_Checkpoints_y_Guardado.md`, `Minijuego_*.md`, `misiones/`) y en las revisiones de audio y DialogueApp.

- `Feature_Checklist.md` queda como **historial** de checkpoints y criterios de aceptación; ya no lleva pendientes.
- Los docs de diseño describen **cómo** se hace algo; aquí solo se anota **qué falta** y en qué orden, con un enlace al doc.
- Prioridad: **P1** = bloquea el primer test jugable · **P2** = siguiente fase · **P3** = backlog / cuando haya tiempo.

---

## 1. Ahora — Fase 2.5: Primer Jugable de Test

Decisiones ya tomadas: el primer test **no** incluye el sistema completo de armas (va en 2.6); Game Over y pantalla de victoria serán un nivel propio más adelante. Audio, niveles del Vertical Slice, orden en Z y plantilla ya están hechos (ver §6).

| # | Pri | Tarea | Ref |
|---|---|---|---|
| 1 | P2 | **Menú de opciones** real (hoy es placeholder dentro de los menús unificados de inicio/pausa, que ya funcionan): volumen y pantalla completa (decisión de Diego, 13 Oct). | `Controles_y_Input.md` |

## 2. Siguiente — Fase 2.6: Combate y Equipamiento

| # | Pri | Tarea | Ref |
|---|---|---|---|
| 1 | P2 | **Armas arrojadizas:** `ThrowableData`, `ThrowComponent`, `projectile.tscn` y munición desde el inventario (los slots de arma ya las aceptan). | `Sistema_Armas_y_Escudo.md` |
| 2 | P2 | **HUD de equipamiento:** falta la munición de las arrojadizas y la posición definitiva. Ya hay un placeholder con el arma activa y el escudo bajo el icono del inventario (`equipment_hud.gd`). | `Sistema_Armas_y_Escudo.md` |
| 3 | P2 | **Diseño definitivo del HUD:** lugar fijo de cada elemento (esquinas, slots, inventario, barra de accesos). Sesión de diseño; va después de las armas (decisión de Diego, 13 Oct). | — |
| 4 | P2 | **Armas y escudos reales:** datos y arte de las armas del juego (hoy solo hay la Espada de Madera y los ítems `test_*`). | — |
| 5 | P2 | **Game Over / Victoria** como nivel propio. | Decisión de Diego (5 Oct) |

## 3. Fase 3: Expansión de Contenido

- [ ] NPCs y diálogo avanzado (`DialogueManager`), voz distinta por NPC.
- [ ] Mazmorras y nuevos niveles interconectados.
- [ ] **Registro de misiones visible:** `QuestAction` existe pero no hay UI de misiones.
- [ ] **Puntos de interés de las quests en el mapa:** conectar `register_poi` / `remove_poi` a las quests reales (siempre visibles, aunque la zona no esté descubierta).
- [ ] **Arte pintado del mapa del mundo** (la grilla y el guardado de lo descubierto ya están; va en rama aparte).
- [ ] **Misiones de minijuegos** (framework de 4 capas: core loop, modificadores, objetivo con 3 estrellas, gancho narrativo). — `misiones/00-sistema-general.md`
- [ ] **Sistema de energía** (`energy` / `max_energy` en `PlayerStats` y snapshots; la Poción Azul ya lo menciona). — `Sistema_Checkpoints_y_Guardado.md`

## 4. Fase 4: Pulido y Lanzamiento

- [ ] Corrección de errores y pruebas de integración.
- [ ] Pulido de UI/UX.
- [ ] **Controles táctiles (Android):** joystick virtual y botones Acción, Secundario, Bloqueo, Mochila, Pausa y slots 1-4.
- [ ] Exportar builds (Desktop / Mobile).

---

## 5. Backlog por área (P3)

### Controles e input
- [ ] Cambio rápido de armas sin abrir el inventario.
- [ ] Hotbar de ítems (consumibles o llaves en el Overworld).

### Audio
- [ ] Variantes (varios archivos) por entrada de `AudioEntry`.
- [ ] Ajustar `cooldown` y `pitch_random` en el catálogo (pasos, tipeo, persecución, golpes).
- [ ] Ambiente por nivel (`amb_level_XX` vía `SceneMusic`), con sonidos provisionales (decisión de Diego, 13 Oct).

### Minijuegos
- **Excavación:** niveles hechos a mano (pintados en TileMap) además del procedimental · enemigo ciego guiado por sonido y sigilo en túneles · ideas de `misiones/02-excavacion.md` (oxígeno con ventilación, contador de pasos).
- **Trampolín:** temas visuales (cielo, noche, espacio, cueva) · variedad de plataformas (móviles, frágiles) y su balance.
- **Smasher:** temas visuales y dianas temáticas · spawners y zonas de salida configurables · variantes de insectos.
- **Catcher:** temas visuales · viento lateral · combos por racha.
- **Runner:** rutas bifurcadas y plataformas altas · enemigos con regla escudo vs. barricada · fondo que cambia en el recorrido.

### Guardado y técnico
- [ ] Tests headless: los runners de `src/core/tests/` no corren con `--script` (decisión actual: QA manual).

### Limpieza del repositorio
- [ ] Decidir qué hacer con el PR #4 (`JoystickAndControls`, abierto) y mergear `FirstPlayableTest` → `develop` cuando el test esté listo.

---

## 6. Hecho

### Marcado como hecho por Diego (13 Oct)
- [x] Archivos de audio asignados en `audio_catalog.tres` (229 entradas con `stream`).
- [x] Vertical Slice: 2 niveles interconectados.
- [x] Orden en Z de toda la escena.
- [x] Plantilla de nivel (cubierta por LevelApp).
- [x] Menú de remapeo de controles.
- [x] Excavación: contador de objetivos en UI.
- [x] Minijuegos Laberinto y Ritmo: cerrados (no hay código en el repo; quedan fuera del roadmap).
- [x] DialogueApp: `switch` con otros operadores, señal de `trigger_event` conectada y pendientes de la revisión.
- [x] Estado actualizado en `Controles_y_Input.md` y `Sistema_Armas_y_Escudo.md`.

### Tanda 1 del plan (13 Oct)
- [x] Antídoto real con efecto de cura (`CureStatusEffect`, cura todos los estados).
- [x] Sin sonidos dobles: se quitaron `sfx_player_invulnerable` y `sfx_enemy_stunned` del mismo frame que el daño.
- [x] `AudioEntry.pitch_random` y `AudioEntry.cooldown` (0 por defecto; botones en `test_audio.tscn`).
- [x] Backup `.bak` de cada slot y lectura del backup si la partida está dañada (`test_save_backup.tscn`).
- [x] PR en borrador #5, #8, #13 y #14 cerrados.

### Tanda 2 del plan (13 Oct)
- [x] El sonido de un golpe lo elige quien lo recibe; golpe bloqueado con `sfx_player_block_hit`. `sfx_player_attack_hit` y `sfx_enemy_attack` quedan sin uso en el catálogo.
- [x] Salida de portal: el jugador aparece en el portal y camina hasta su `SpawnPoint` (`test_portal_exit.tscn`).
- [x] `sfx_enemy_attack_windup` al entrar en rango de ataque y `sfx_player_low_health` al bajar del 25% de vida (sonidos proxy).
- [x] Sonido posicional `AudioManager.play_sfx_at` en enemigos y dummies.
- [x] Ítems `test_*` movidos a `src/core/tests/items/` (ya no aparecen en el juego ni en LevelApp).

### Tanda 4 del plan: Equipamiento y Escudo (13 Oct)
- [x] Equipamiento: 2 slots de arma (una activa, se alterna con `weapon_prev` / `weapon_next`) y 1 de escudo, guardados en la partida (`Inventory.equipped`). Se equipa desde el inventario o un slot rápido.
- [x] `WeaponData` (daño, cooldown, alcance, knockback, visual y estado) y `WeaponComponent`; sin arma, golpe base.
- [x] Escudo completo: `ShieldData` con `coverage_angle`, `block_percent`, velocidad al bloquear y estados que detiene; sin escudo no se bloquea.
- [x] Variables `equip.weapon_1`, `equip.weapon_2`, `equip.shield` y `equip.active`.
- [x] Los golpes con estado (veneno) vuelven a aplicarlo al jugador: antes los i-frames del mismo golpe lo anulaban.
- [x] Prueba `src/core/tests/test_weapons.tscn` (reemplaza a `test_shield.tscn`).
- [x] Slots rápidos: un arma o escudo se intercambia con lo equipado (lo que llevabas queda en el slot); un consumible agotado deja el slot vacío (pedido de Diego, 13 Oct).
- [x] Ítems placeholder para probar: Espada de Hierro, Escudo de Madera y Escudo de Hierro (iconos provisionales).
- [x] Tanda 3 decidida: opciones con pantalla completa, HUD después de las armas, ambiente provisional y Runner sin D-Pad lateral.

### Fase 1: Prototipo
- [x] Movimiento (grilla 60x60, colisiones, cámara con límites por nivel).
- [x] Interacción: Actionable, cofres, puertas, portales, palancas y placas de presión.
- [x] Eventos y triggers (`GameTrigger`, `DoorAction`, `DestroyNodeAction`).
- [x] Enemigos en Overworld (patrulla, detección, persecución, `LootDropComponent`).
- [x] Inventario base y UI.

### Fase 2: Minijuegos y bucle principal
- [x] 5 minijuegos (Excavación, Catcher, Runner, Smasher, Trampolín) sobre `MinigameBase` con victoria/derrota uniforme.
- [x] Recompensas de minijuegos al `Inventory` y retorno al Overworld con nivel y spawn.
- [x] Herramientas de configuración y balance.

### Fase 2.5 (hasta ahora)
- [x] Limpieza integral del código (29 Sep).
- [x] `GameVariables`, condiciones y `VariableWatcher`, integrados con DialogueApp.
- [x] Estados alterados (`StatusEffectData`) y efectos de ítems.
- [x] Texto de puerta cerrada y pausa durante diálogos.
- [x] Sistema de audio: `AudioManager`, catálogo de 229 IDs, música por escena, volumen.
- [x] Escudo proxy: bloquea daño y estados, conserva knockback, sin movimiento al bloquear.
- [x] Enemigos que paran a distancia de ataque y vuelven a perseguir si el jugador se aleja.
- [x] Puertas y portales bloqueados mientras haya enemigos vivos.
- [x] Sin zumbido ambiental en portales.
- [x] Smasher: radio de impacto mayor que la mira · Catcher: tiempo en suelo regulable.
- [x] Capas de tilemap y y-sort (`Capas_y_Orden_Z.md`): solo `PropsLayer` colisiona; árboles en una sola capa.
- [x] Tileset proxy (Kenney medieval) en `core_tileset.tres`.

### Controles y joystick (esquema unificado)
Abajo = Acción, izquierda = Secundario, arriba = Inventario, derecha = Comodín/Atrás, Start = Pausa. Mapa completo en la hoja "Gacheiducitos - Mapa de Controles" (Drive).
- [x] Acciones de gameplay separadas de las `ui_*`; mapeos extra limpiados; D-Pad = slots en Overworld.
- [x] Teclado nuevo (K ataca, L bloquea, Tab/I inventario, P pausa, Esc atrás, E/Espacio/Enter acción).
- [x] Bloqueo (`block`) conectado al escudo proxy.
- [x] Asignación de slots desde el inventario.
- [x] Pausa y menú de inicio unificados (con "Abandonar minijuego").
- [x] Runner, Smasher y pausa de minijuegos con mando; diálogos con avance y avance rápido; F3 en el InputMap.
- [x] Mapa del mundo con descubrimiento progresivo y sus controles.

### Herramientas
- [x] LevelApp: editor visual, NPC = `npc_barnaby.tscn`, diálogos en NPC y Trigger, música por nivel, colisiones visibles y suelo checker.
- [x] DialogueApp: guardado sin pérdidas, parser modular, servidor solo en 127.0.0.1, vistas Escritura y Nodos, undo/redo.
- [x] Versión web de LevelApp y DialogueApp en Firebase (`levelapp-f4d64`) con login y lista de accesos; soporte táctil retirado.
