# Hoja de Ruta del Proyecto (Roadmap)

**Actualizado:** 13 de Octubre, 2026 · rama `FirstPlayableTest`

Esta es la **única lista de tareas pendientes** del proyecto. Unifica lo que antes estaba repartido en este archivo, en `Feature_Checklist.md` (sección "Tareas Pendientes" y las features 🟡), en los `TODO` del código, en los docs de diseño (`Sistema_Armas_y_Escudo.md`, `Controles_y_Input.md`, `Capas_y_Orden_Z.md`, `Sistema_Checkpoints_y_Guardado.md`, `Minijuego_*.md`, `misiones/`) y en las revisiones de audio y DialogueApp.

- `Feature_Checklist.md` queda como **historial** de checkpoints y criterios de aceptación; ya no lleva pendientes.
- Los docs de diseño describen **cómo** se hace algo; aquí solo se anota **qué falta** y en qué orden, con un enlace al doc.
- Prioridad: **P1** = bloquea el primer test jugable · **P2** = siguiente fase · **P3** = backlog / cuando haya tiempo.

---

## 1. Ahora — Fase 2.5: Primer Jugable de Test

Decisiones ya tomadas: el primer test **no** incluye el sistema completo de armas (va en 2.6); Game Over y pantalla de victoria serán un nivel propio más adelante; los niveles de test los arma Diego con LevelApp.

| # | Pri | Tarea | Ref |
|---|---|---|---|
| 1 | P1 | **Archivos de audio** asignados en `data/audio/audio_catalog.tres` (hoy las 229 entradas tienen `stream` vacío y el juego es mudo). Empezar por el set mínimo de ~20 IDs (pasos, ataque, bloqueo, daño, muerte, enemigo, pickups, UI, diálogo, `music_level_01`). Opción rápida: script que genere WAVs tipo sfxr y los asigne. | `Sistema_Audio.md`, `revisiones/sonidos-revision.md` |
| 2 | P1 | **Sonido de golpe bloqueado** (`sfx_player_block_hit`) y mover el sonido del golpe al receptor (hoy `HitboxComponent` suena antes de saber si hubo daño, así que un bloqueo suena como un golpe). | `revisiones/sonidos-revision.md` |
| 3 | P1 | **Vertical Slice: 2 niveles interconectados** armados con LevelApp (los hace Diego siguiendo la guía). | `Guia_Creacion_Niveles.md` |
| 4 | P1 | **Orden en Z de toda la escena:** interactuables, efectos, proyectiles, minijuegos y UI (las capas de tilemap ya están resueltas). | `Capas_y_Orden_Z.md` §5 |
| 5 | P2 | **Animación de salida de portal:** el personaje aparece en el portal y camina solo hasta el arrival point. | `TODO` en `src/core/game_manager.gd:209` |
| 6 | P2 | **Menú de opciones** real (hoy es placeholder dentro de los menús unificados de inicio/pausa, que ya funcionan). | `Controles_y_Input.md` |
| 7 | P3 | Plantilla de nivel (`template_level.tscn`): confirmar si LevelApp la reemplaza; si no, recrearla. El PR #5 tiene una versión en borrador. | PR #5 |

## 2. Siguiente — Fase 2.6: Combate y Equipamiento

| # | Pri | Tarea | Ref |
|---|---|---|---|
| 1 | P2 | **Equipamiento:** 2 slots de arma (cuerpo a cuerpo o arrojadiza, una activa; atacar con arrojadiza = lanzar) + escudo, asignables desde el inventario. Las armas no se mejoran, solo se cambian. | `Sistema_Armas_y_Escudo.md` |
| 2 | P2 | **Escudo completo:** `ShieldData`, `coverage_angle`, `block_percent` y requerir escudo equipado (hoy es un proxy de 360°). | `TODO(escudo)` en `shield_component.gd:55` |
| 3 | P2 | **Efecto real de los 4 slots rápidos** (cambiar arma, cambiar escudo, consumir poción). Entrada, HUD y asignación desde el inventario ya están. | `Controles_y_Input.md` |
| 4 | P2 | **HUD de equipamiento:** iconos de las 2 armas (activa resaltada, munición si es arrojadiza) y del escudo. | `Sistema_Armas_y_Escudo.md` |
| 5 | P2 | **Diseño definitivo del HUD:** lugar fijo de cada elemento (esquinas, slots, inventario, barra de accesos). Sesión de diseño. | — |
| 6 | P2 | **Game Over / Victoria** como nivel propio. | Decisión de Diego (5 Oct) |
| 7 | P2 | Contenido: efectos del ítem **Antídoto**; borrar ítems `test_*` cuando ya no se usen. | — |

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
- [ ] Menú de remapeo de controles.
- [ ] Runner: evaluar desplazamiento lateral con D-Pad izquierda/derecha.

### Audio
- [ ] `pitch_random` y variantes por entrada (`AudioEntry`).
- [ ] Cooldown anti-spam por ID (pasos, tipeo, persecución con varios enemigos).
- [ ] Sonido posicional: `AudioManager.play_sfx_at(id, pos)` con pool de `AudioStreamPlayer2D`.
- [ ] Nuevos IDs: `sfx_enemy_attack_windup`, `amb_level_XX` (ambiente por nivel), `sfx_player_low_health`.
- [ ] Quitar sonidos dobles del mismo frame (`hurt` + `invulnerable`, `enemy_hurt` + `enemy_stunned`).

### Minijuegos
- **Excavación:** niveles hechos a mano (pintados en TileMap) además del procedimental · enemigo ciego guiado por sonido y sigilo en túneles · contador de objetivos en UI · ideas de `misiones/02-excavacion.md` (oxígeno con ventilación, contador de pasos).
- **Trampolín:** temas visuales (cielo, noche, espacio, cueva) · variedad de plataformas (móviles, frágiles) y su balance.
- **Smasher:** temas visuales y dianas temáticas · spawners y zonas de salida configurables · variantes de insectos.
- **Catcher:** temas visuales · viento lateral · combos por racha.
- **Runner:** rutas bifurcadas y plataformas altas · enemigos con regla escudo vs. barricada · fondo que cambia en el recorrido.
- **Nuevos minijuegos (solo diseño, sin código):** Laberinto (niebla de guerra, muros que cambian fuera de cámara, wraparound, enemigos que drenan luz) — `Minijuego_Laberinto.md` · Ritmo (metrónomo por BPM, ventana de timing, secuencias de comandos) — sin doc todavía.

### Herramientas (LevelApp, DialogueApp, web)
- [ ] DialogueApp: comprobar el `switch` con operadores distintos de `==` (la pérdida de `do` en nodos con texto ya está resuelta: el test de round-trip pasa, 168/168).
- [ ] DialogueApp: conectar en Godot la señal de `GameManager.trigger_event(...)` que generan los nodos de evento.
- [ ] DialogueApp: pendientes de la revisión que no entraron en los arreglos (referencias de `conditionOutputs` al renombrar/borrar, layout guardado por título, rendimiento del canvas). — `revisiones/dialogueapp-revision.md`

### Guardado y técnico
- [ ] Backup `.bak` de las partidas guardadas.
- [ ] Tests headless: los runners de `src/core/tests/` no corren con `--script` (decisión actual: QA manual).
- [ ] Actualizar el "Estado" de `Controles_y_Input.md` y `Sistema_Armas_y_Escudo.md`, que todavía dicen "sin código".

### Limpieza del repositorio
- [ ] Cerrar los PR en borrador cuyo contenido ya está en `FirstPlayableTest`: #13 (puertas bloqueadas por enemigos) y #14 (capas de tilemap). Decidir #5 (plantilla) y #8 (roadmap viejo, reemplazado por este).
- [ ] Decidir qué hacer con el PR #4 (`JoystickAndControls`, abierto) y mergear `FirstPlayableTest` → `develop` cuando el test esté listo.

---

## 6. Hecho

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
