# Especificación: Sistema de Armas, Escudo y Armas Arrojadizas

**Fecha:** 29 de Septiembre, 2026
**Proyecto:** RPG-G (Godot 4.6)
**Estado:** Diseño aprobado — pendiente de implementación (sin código)

---

## 1. Visión General

El jugador tiene **tres slots de equipamiento**: dos de arma y uno de escudo.

| Slot | Contenido | Uso |
|---|---|---|
| **Arma 1** | Cualquier arma (cuerpo a cuerpo o arrojadiza) | Botón Atacar, si es la activa |
| **Arma 2** | Cualquier arma (cuerpo a cuerpo o arrojadiza) | Botón Atacar, si es la activa |
| **Escudo** | Escudo | Botón Escudo (mantener) |

Reglas:
- Solo **una de las dos armas está activa**. El botón **Atacar usa el arma activa**: si es cuerpo a cuerpo golpea, si es arrojadiza lanza. No hay botón aparte para lanzar.
- Se alterna el arma activa con `weapon_prev` / `weapon_next` (Q/R, rueda del ratón, LB/RB).
- El equipamiento se asigna **desde el inventario**. Lo que no está equipado permanece en el inventario como un ítem más.
- Las armas **no se mejoran**: solo se cambian por otras.
- Armas y escudos son **ítems** (`ItemData`) y se obtienen como cualquier ítem (pickup, cofre, recompensa, `ItemAction`).
- Cada slot puede estar vacío. Si el arma activa está vacía, el ataque es el golpe base con `PlayerStats.get_strength()`. Sin escudo no se puede bloquear.

## 2. Datos (Custom Resources, editables en el Inspector)

Ubicación: `rpg-g/data/resource_types/equipment/`.

### 2.1 `EquipmentData` (base)
- `kind: Kind` (`MELEE`, `THROWABLE`, `SHIELD`). Las de tipo `MELEE` y `THROWABLE` van en los slots de arma; `SHIELD` en el de escudo.
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
- **Munición:** cada lanzamiento consume 1 unidad del ítem en el inventario (por ejemplo, flechas apiladas). Sin unidades no se puede lanzar. Los proyectiles lanzados **no se recuperan**; solo se recogen ítems (pickups).

### 2.5 `ItemData`
- Nuevo campo `equipment: EquipmentData` (grupo "Equipamiento"). Si tiene valor, el ítem es equipable (en un slot de arma o en el de escudo, según su `kind`).

---

## 3. Estado del Equipamiento y Persistencia

- `Inventory` guarda los slots equipados y cuál arma está activa: `equipped = {"weapon_1": item_id, "weapon_2": item_id, "shield": item_id}` y `active_weapon = 1 | 2`.
- API propuesta:
  - `equip(item_id, slot) -> bool` (lo que ocupaba el slot vuelve al inventario)
  - `unequip(slot) -> void`
  - `get_equipped(slot) -> ItemData`, `get_active_weapon() -> ItemData`
  - `switch_active_weapon() -> void`
  - señales `equipment_changed(slot: String, item_id: String)` y `active_weapon_changed(slot: String)`
- Un arma cuerpo a cuerpo o un escudo equipado **no aparece** en la lista del inventario (sale mientras está equipado y vuelve al desequiparlo).
- Una arrojadiza equipada con munición apilada: el slot referencia el ítem y el contador del inventario es la munición disponible.
- `create_snapshot` / `restore_snapshot` de `Inventory` incluyen `equipped` (compatibles con saves antiguos: si falta la clave, slots vacíos).
- Variables (`GameVariables`, solo lectura): `equip.weapon_1`, `equip.weapon_2`, `equip.shield`, `equip.active` → id del ítem o `""`. Permite condiciones como "si llevas el escudo de madera".

---

## 4. Componentes del Jugador (composición)

| Nodo (hijo de Player) | Script | Responsabilidad |
|---|---|---|
| `WeaponComponent` | `weapon_component.gd` | Al pulsar Atacar usa el arma activa: si es cuerpo a cuerpo configura el `HitboxComponent` (daño = fuerza + daño del arma, alcance, knockback, estado, visual); si es arrojadiza delega en `ThrowComponent`. Gestiona el cooldown y el cambio de arma activa. |
| `ShieldComponent` | `shield_component.gd` | Mientras se mantiene Escudo: estado "bloqueando", velocidad reducida, no se puede atacar. Filtra los golpes entrantes según `coverage_angle`, `block_percent` y los estados bloqueados. |
| `ThrowComponent` | `throw_component.gd` | Lanza el proyectil del arma activa (arrojadiza) en la dirección que mira el jugador, consumiendo 1 unidad de munición. |

- El `HurtboxComponent` ya recibe la dirección del golpe (`attack_direction`); `ShieldComponent` la compara con la dirección del jugador para decidir si el golpe está dentro del ángulo cubierto.
- Proyectiles: escena `projectile.tscn` (`Area2D` + `HitboxComponent`) en `rpg-g/src/core/components/`; se destruye al impactar o al superar `max_range`.

### Señales
- `Inventory.equipment_changed(slot, item_id)` y `active_weapon_changed(slot)` → `WeaponComponent` / `ShieldComponent` / HUD se reconfiguran.
- `ShieldComponent.block_started` / `block_ended` / `hit_blocked(amount_blocked)` → feedback visual/sonoro.

---

## 5. UI

- **Inventario:** sección de 3 slots (Arma 1 / Arma 2 / Escudo). Un ítem equipable se asigna al slot elegido; clic en un slot lo desequipa.
- **HUD:** iconos de las 2 armas (resaltando la activa, con la munición si es arrojadiza) y del escudo (posición definitiva pendiente del diseño de HUD).

---

## 6. Controles

Según `design/Controles_y_Input.md`: Atacar (J / clic izq. / X-▢) usa el arma activa, Escudo (K / clic der. / LT-L2), y alternar arma activa con `weapon_prev` / `weapon_next` (Q/R, rueda, LB/RB). No hay botón de lanzar.

---

## 7. Decisiones Tomadas

1. **Munición:** las arrojadizas consumen unidades del inventario.
2. **Recuperación:** los proyectiles no se recogen; solo se recogen ítems.
3. **Slots:** dos slots de arma (cualquier tipo) con una activa; atacar con una arrojadiza activa es lanzar.
4. **Enemigos:** por ahora escudo y arrojadizas son solo del jugador. Eventualmente habrá enemigos con escudo y arrojadizas, así que los componentes (`ShieldComponent`, proyectiles con `HitboxComponent`) deben diseñarse reutilizables y no depender del jugador.

---

## 8. Escena de Prueba (al implementar)

`rpg-g/src/core/tests/test_weapons.tscn`: jugador, muñecos de práctica (`dummy_npc.tscn`), pickups de 1 arma cuerpo a cuerpo, 1 arrojadiza con munición, 1 escudo de prueba (`test_*`), y un enemigo que ataca de frente para validar el ángulo de cobertura del escudo.

---

## 9. Proyectos Futuros Relacionados (fuera de alcance)

- **Cambio rápido de armas:** elegir cualquier arma del inventario sin abrirlo (más allá de alternar entre los 2 slots).
- **Selección rápida de ítems (hotbar):** usar consumibles sin abrir el inventario.
