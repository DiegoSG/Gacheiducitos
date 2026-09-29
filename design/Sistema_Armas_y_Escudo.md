# Especificación: Sistema de Armas, Escudo y Armas Arrojadizas

**Fecha:** 29 de Septiembre, 2026
**Proyecto:** RPG-G (Godot 4.6)
**Estado:** Diseño aprobado — pendiente de implementación (sin código)

---

## 1. Visión General

El jugador tiene **tres slots de equipamiento**:

| Slot | Contenido | Uso |
|---|---|---|
| **Arma** | Arma cuerpo a cuerpo | Botón Atacar |
| **Escudo** | Escudo | Botón Escudo (mantener) |
| **Arrojadiza** | Arma arrojadiza (flechas, cuchillos, piedras...) | Botón propio de lanzar (ver sección 6) |

Reglas:
- El equipamiento se asigna **desde el inventario**. Lo que no está equipado permanece en el inventario como un ítem más.
- Las armas **no se mejoran**: solo se cambian por otras.
- Armas, escudos y arrojadizas son **ítems** (`ItemData`) y se obtienen igual que cualquier ítem (pickup, cofre, recompensa, `ItemAction`).
- Cada slot puede estar vacío (sin arma = ataque base con `PlayerStats.get_strength()`; sin escudo = no se puede bloquear; sin arrojadiza = no se puede lanzar).

---

## 2. Datos (Custom Resources, editables en el Inspector)

Ubicación: `rpg-g/data/resource_types/equipment/`.

### 2.1 `EquipmentData` (base)
- `slot: Slot` (`WEAPON`, `SHIELD`, `THROWABLE`)
- `display_name`, `icon` (el ítem ya los tiene; solo se usan si difieren)

### 2.2 `WeaponData` (cuerpo a cuerpo) — extiende `EquipmentData`
- `damage: int` — se suma a `PlayerStats.get_strength()`.
- `cooldown: float` — segundos entre ataques.
- `reach: Vector2` — tamaño de la zona de golpe (hitbox).
- `knockback: float`
- `slash_texture: Texture2D` — visual del golpe.
- `status_effect: StatusEffectData` + `status_chance: float` (0–100) — opcional, estado que inflige al golpear (reutiliza el sistema de estados existente).

### 2.3 `ShieldData` — extiende `EquipmentData`
- `block_percent: float` (0–100) — porcentaje de daño bloqueado. **Configurable.**
- `coverage_angle: float` (grados) — ángulo de cobertura centrado en la dirección que mira el jugador. **Configurable.**
- `move_speed_multiplier: float` — velocidad mientras se bloquea.
- `blocks_statuses: bool` — si protege de estados alterados. **Configurable.**
- `blocked_status_ids: Array[String]` — qué estados bloquea (vacío + `blocks_statuses = true` = todos). **Configurable.**

### 2.4 `ThrowableData` — extiende `EquipmentData`
- `projectile_scene: PackedScene` — escena del proyectil (flecha, cuchillo...).
- `damage: int`, `speed: float`, `max_range: float`, `cooldown: float`
- `status_effect: StatusEffectData` + `status_chance: float` — opcional.
- `consumes_ammo: bool` — ver decisión pendiente 7.1.

### 2.5 `ItemData`
- Nuevo campo `equipment: EquipmentData` (grupo "Equipamiento"). Si tiene valor, el ítem es equipable en el slot que indique.

---

## 3. Estado del Equipamiento y Persistencia

- `Inventory` guarda los slots equipados: `equipped = {"weapon": item_id, "shield": item_id, "throwable": item_id}`.
- API propuesta:
  - `equip(item_id) -> bool` (lo coloca en el slot de su `EquipmentData`; lo que ocupaba el slot vuelve al inventario)
  - `unequip(slot) -> void`
  - `get_equipped(slot) -> ItemData`
  - señal `equipment_changed(slot: String, item_id: String)`
- Un ítem equipado **no aparece** en la lista del inventario (sale del stack mientras está equipado y vuelve al desequiparlo).
- `create_snapshot` / `restore_snapshot` de `Inventory` incluyen `equipped` (compatibles con saves antiguos: si falta la clave, slots vacíos).
- Variables (`GameVariables`, solo lectura): `equip.weapon`, `equip.shield`, `equip.throwable` → id del ítem equipado o `""`. Permite condiciones como "si llevas el escudo de madera".

---

## 4. Componentes del Jugador (composición)

| Nodo (hijo de Player) | Script | Responsabilidad |
|---|---|---|
| `WeaponComponent` | `weapon_component.gd` | Aplica el arma equipada al `HitboxComponent` (daño = fuerza + daño del arma, alcance, knockback, estado, visual) y gestiona el cooldown del ataque. |
| `ShieldComponent` | `shield_component.gd` | Mientras se mantiene Escudo: estado "bloqueando", velocidad reducida, no se puede atacar. Filtra los golpes entrantes según `coverage_angle`, `block_percent` y los estados bloqueados. |
| `ThrowComponent` | `throw_component.gd` | Lanza el proyectil del slot arrojadizo en la dirección que mira el jugador, respetando cooldown y munición. |

- El `HurtboxComponent` ya recibe la dirección del golpe (`attack_direction`); `ShieldComponent` la compara con la dirección del jugador para decidir si el golpe está dentro del ángulo cubierto.
- Proyectiles: escena `projectile.tscn` (`Area2D` + `HitboxComponent`) en `rpg-g/src/core/components/`; se destruye al impactar o al superar `max_range`.

### Señales
- `Inventory.equipment_changed(slot, item_id)` → `WeaponComponent` / `ShieldComponent` / `ThrowComponent` / HUD se reconfiguran.
- `ShieldComponent.block_started` / `block_ended` / `hit_blocked(amount_blocked)` → feedback visual/sonoro.

---

## 5. UI

- **Inventario:** sección de 3 slots (Arma / Escudo / Arrojadiza). Doble clic o botón "Equipar" en un ítem equipable lo coloca en su slot; clic en un slot lo desequipa.
- **HUD:** iconos pequeños de los 3 slots equipados (posición definitiva pendiente del diseño de HUD).

---

## 6. Controles

Según `design/Controles_y_Input.md`: Atacar (J / clic izq. / X-▢) y Escudo (K / clic der. / LT-L2) ya están definidos. **Lanzar arrojadiza** necesita acción propia: propuesta en ese documento (`throw`), a confirmar.

---

## 7. Decisiones Pendientes (usuario)

1. **Munición de arrojadizas:** ¿cada lanzamiento consume una unidad del ítem (flechas apiladas en el inventario) o son infinitas?
2. **Recuperación:** ¿los proyectiles lanzados se pueden recoger del suelo?
3. **Botón de lanzar:** confirmar la tecla/botón propuesto en `Controles_y_Input.md`.
4. **Enemigos con escudo o arrojadizas:** ¿solo el jugador por ahora?

---

## 8. Escena de Prueba (al implementar)

`rpg-g/src/core/tests/test_weapons.tscn`: jugador, muñecos de práctica (`dummy_npc.tscn`), pickups de 2 armas, 1 escudo y 1 arrojadiza de prueba (`test_*`), y un enemigo que ataca de frente para validar el ángulo de cobertura del escudo.

---

## 9. Proyectos Futuros Relacionados (fuera de alcance)

- **Cambio rápido de armas:** alternar entre armas del inventario sin abrirlo (ej. rueda o anterior/siguiente). Las acciones `weapon_prev` / `weapon_next` ya quedan reservadas en el mapa de controles.
- **Selección rápida de ítems (hotbar):** usar consumibles sin abrir el inventario.
