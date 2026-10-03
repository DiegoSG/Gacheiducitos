# Guía de Plantas de Nivel (Level Layout)

Complementa `Guia_Creacion_Niveles.md`. Plantilla técnica: `rpg-g/src/overworld/levels/level_template.tscn`
(duplicar con *Scene ➔ Save Scene As…*, nombrar en `snake_case`, renombrar el nodo raíz en `PascalCase`).

Referencias de diseño: **Zelda** (Link's Awakening / ALttP: pantallas legibles, llaves y progresión por zonas),
**Ogu y el bosque secreto** (exploración amable, caminos claros, secretos cerca del camino principal) y
**Garden Story** (mundo cálido y compacto, hubs con muchos NPC, recompensas pequeñas y frecuentes).
Son inspiración de ritmo y legibilidad, no se copian mapas.

## 1. Medidas base
| Concepto | Valor | Notas |
|---|---|---|
| Tile | 60x60 px | `core_tileset.tres`; todo se alinea a la grilla |
| Pantalla (viewport) | 1920x1080 px = **32x18 tiles** | Unidad de diseño de una "sala" |
| Pasillo mínimo | 3 tiles (180 px) | Jugador + margen para esquivar |
| Pasillo cómodo / camino principal | 4-6 tiles | Que se lea como camino sin pintarlo de otro color |
| Puerta / portal | 2 tiles de ancho | Colocar sobre el borde del nivel o en un muro |
| Centro de tile | `30 + 60·n` | Posiciones de nodos (spawn, NPC) centradas |

La plantilla viene en **1 pantalla** (`WorldBoundaryManager` 1920x1080). Para niveles más grandes usar múltiplos de pantalla:

| Formato | width x height | Uso típico |
|---|---|---|
| Sala (1x1) | 1920 x 1080 | Interior, casa, mazmorra-sala, jefe |
| Pasillo (2x1 / 1x2) | 3840 x 1080 / 1920 x 2160 | Puentes, cuevas, transiciones |
| Zona (2x2) | 3840 x 2160 | Bosque, aldea pequeña (tamaño por defecto del script) |
| Hub grande (3x2 o 3x3) | 5760 x 2160 / 5760 x 3240 | Pueblo central; evitar más: la exploración se vuelve vacía |

## 2. Estructura de la plantilla
```
LevelTemplate (Node2D, y_sort)
├─ WorldBoundaryManager   límites + colisión invisible (width/height)
├─ Environment
│  ├─ GroundLayer         suelo base (sin colisión de obstáculo)
│  ├─ DetailLayer         flores, caminos, grietas (decorativo)
│  └─ PropsLayer          árboles, rocas, muros (con colisión, y_sort)
├─ SpawnPoints
│  └─ SpawnStart          ArrivalSpawnPoint arrival_id="start"
├─ Portals                LevelPortal (cambios de nivel / puertas)
├─ Entities
│  ├─ NPCs
│  ├─ Enemies
│  └─ Interactables       Chest, PickupItem, PressurePlate, Switch, Minigame…
├─ Triggers               DialogueEvent y otros GameTrigger
└─ Player                 sobre SpawnStart (BoundedCamera ya incluida)
```
Los contenedores están vacíos: arrastrar cada escena a su contenedor para mantener el orden del árbol.
Todo interactable con estado necesita `persistence_id` único (skill `godot-level-builder`).

## 3. Cómo diseñar una planta (paso a paso)
1. **Propósito en una frase**: qué hace el jugador aquí (conocer a un NPC, conseguir la llave, pasar por un minijuego).
2. **Bosquejo en papel/cuadrícula** de 32x18 por pantalla. Marcar primero entradas y salidas.
3. **Camino principal**: una ruta clara de la entrada a la salida (4-6 tiles de ancho). El jugador debe poder intuirla sin texto.
4. **Zonas**: dividir el mapa en 3-5 zonas con identidad (ver §4). Separarlas con cuellos de botella (2-3 tiles) o cambios de terreno.
5. **Puntos de interés (PdI)**: cada pantalla tiene 1 PdI visible desde lejos (árbol grande, torre, humo) y 1-2 detalles pequeños.
6. **Secretos**: cerca del camino principal, insinuados (grieta, hilera de flores, árbol aislado), nunca lejos y sin pista.
7. **Colocar entidades** en orden: spawns y portales ➔ NPC ➔ interactables ➔ enemigos ➔ triggers.
8. **Pintar**: Ground ➔ Props (colisión) ➔ Detail.
9. **Validar** con el checklist de §6.

## 4. Principios tomados de las referencias
- **Una pantalla = una idea** (Zelda): cada 32x18 tiene un objetivo o puzzle legible sin salir de cuadro.
- **Hub y rama** (Garden Story): una zona central segura con NPC y salidas hacia ramas más cortas con recompensa.
- **Bosque con claros** (Ogu): zonas abiertas conectadas por senderos estrechos; el follaje (Props) guía y oculta secretos.
- **Cerrojo y llave**: una puerta o barrera visible antes de conseguir su llave (`LevelPortal.key`), para que el jugador recuerde dónde volver.
- **Atajos de vuelta**: tras una zona difícil, un camino corto que regresa al hub.
- **Enemigos**: grupos de 1-3, lejos de la entrada (mínimo 6 tiles al `SpawnStart`) y fuera de los cuellos de botella.
- **Descanso**: tras un reto, un claro con cofre/NPC antes del siguiente.
- **Seguridad**: los bordes del mapa y las entradas no deben tener enemigos ni trampas en el radio de aparición del jugador.

## 5. Convención de IDs
- Spawn inicial: `start`. Portales: `from_<origen>`; minijuegos: `from_<mg>_win` / `from_<mg>_lose`.
- Cada `exit_id` de un portal debe existir como `arrival_id` en el nivel destino (verificar ida y vuelta).

## 6. Checklist de la planta
- [ ] `WorldBoundaryManager` cubre toda el área jugable (múltiplos de 1920x1080 o de 60 px).
- [ ] Hay camino principal claro de entrada a salida, de ≥3 tiles.
- [ ] Cada pantalla tiene un PdI y no hay zonas vacías de más de 1 pantalla sin nada.
- [ ] Los secretos se pueden intuir desde el camino principal.
- [ ] Spawns, portales e IDs coinciden en ambos niveles; `persistence_id` únicos.
- [ ] Nada colisiona con el spawn ni queda atrapado entre Props.
