extends Node2D

## Prueba de equipamiento y escudo (design/Sistema_Armas_y_Escudo.md).
## Al abrir la escena corre comprobaciones automáticas (PASS/FAIL por consola y en pantalla),
## deja el equipo vacío y la escena queda lista para probar a mano con los pickups.

const SWORD_ID: String = "wooden_sword"
const CLUB_ID: String = "test_heavy_club"
const SHIELD_ID: String = "test_wooden_shield"
const HALF_SHIELD_ID: String = "test_half_shield"

## Ítems de prueba fuera de data/items: se registran en ItemDatabase al abrir la escena.
@export var test_items: Array[Resource] = []

@onready var _player: CharacterBody2D = $Player
@onready var _result_label: Label = %ResultLabel

var _failures: int = 0

func _ready() -> void:
	for item: Resource in test_items:
		ItemDatabase.register_item(item as ItemData)
	# Esperar a que el jugador termine su _ready y entre al árbol de física
	await get_tree().process_frame
	await get_tree().physics_frame
	await _run_checks()
	_reset_state()
	var summary: String = "PASS: equipamiento y escudo" if _failures == 0 else "FAIL: %d comprobaciones fallaron" % _failures
	print(summary)
	_result_label.text = summary

func _run_checks() -> void:
	_reset_state()
	var weapon: WeaponComponent = _player.get_node("WeaponComponent")
	var shield: ShieldComponent = _player.get_node("ShieldComponent")

	# --- Equipar y desequipar ---
	Inventory.add_item(SWORD_ID)
	Inventory.add_item(CLUB_ID)
	Inventory.add_item(SHIELD_ID)
	_check(Inventory.equip(SWORD_ID, Inventory.SLOT_WEAPON_1), "equipa la espada en Arma 1")
	_check(Inventory.get_item_count(SWORD_ID) == 0, "la espada equipada sale de la lista")
	_check(Inventory.get_owned_count(SWORD_ID) == 1, "item.wooden_sword sigue contando la espada")
	_check(weapon.weapon == Inventory.get_equipped(Inventory.SLOT_WEAPON_1).equipment, "el jugador usa el arma activa")
	_check(not Inventory.equip(SHIELD_ID, Inventory.SLOT_WEAPON_2), "un escudo no entra en un slot de arma")
	_check(not Inventory.equip(SWORD_ID, Inventory.SLOT_SHIELD), "un arma no entra en el slot de escudo")
	_check(Inventory.equip(CLUB_ID, Inventory.SLOT_WEAPON_1), "reemplaza el arma del slot")
	_check(Inventory.get_item_count(SWORD_ID) == 1, "el arma reemplazada vuelve al inventario")
	_check(weapon.get_damage(PlayerStats.get_strength()) == PlayerStats.get_strength() + 3, "daño = fuerza + daño del arma")
	_check(Inventory.equip(SWORD_ID, Inventory.SLOT_WEAPON_2), "equipa la espada en Arma 2")

	# --- Alternar e intercambiar ---
	Inventory.switch_active_weapon()
	_check(Inventory.active_weapon == Inventory.SLOT_WEAPON_2, "alterna el arma activa")
	_check(GameVariables.get_var("equip.active") == SWORD_ID, "equip.active refleja el arma activa")
	_check(weapon.weapon == ItemDatabase.get_item(SWORD_ID).equipment, "el jugador cambia al arma activa")
	_check(Inventory.equip(SWORD_ID, Inventory.SLOT_WEAPON_1), "mover un arma al otro slot")
	_check(Inventory.get_equipped_id(Inventory.SLOT_WEAPON_2) == CLUB_ID, "los dos slots de arma se intercambian")
	Inventory.unequip(Inventory.SLOT_WEAPON_2)
	_check(Inventory.get_item_count(CLUB_ID) == 1 and Inventory.get_equipped_id(Inventory.SLOT_WEAPON_2) == "", "desequipar devuelve el arma")
	_check(weapon.weapon == null, "con el slot activo vacío el golpe es el base")

	# --- Guardado ---
	_check(Inventory.equip(SHIELD_ID, Inventory.SLOT_SHIELD), "equipa el escudo")
	_check(GameVariables.get_var("equip.shield") == SHIELD_ID, "equip.shield refleja el escudo")
	var snapshot: Dictionary = Inventory.create_snapshot()
	Inventory.restore_snapshot({})
	_check(Inventory.get_equipped_id(Inventory.SLOT_SHIELD) == "", "un save sin equipo deja los slots vacíos")
	Inventory.restore_snapshot({CLUB_ID: 2})
	_check(Inventory.get_item_count(CLUB_ID) == 2, "lee el formato antiguo de inventario")
	Inventory.restore_snapshot(JSON.parse_string(JSON.stringify(snapshot)))
	_check(Inventory.get_equipped_id(Inventory.SLOT_WEAPON_1) == SWORD_ID and Inventory.get_equipped_id(Inventory.SLOT_SHIELD) == SHIELD_ID, "restaura el equipo tras pasar por JSON")
	_check(Inventory.active_weapon == Inventory.SLOT_WEAPON_2, "restaura el arma activa")
	_check(shield.shield_data == ItemDatabase.get_item(SHIELD_ID).equipment, "el jugador recibe el escudo restaurado")

	Inventory.restore_snapshot({"items": {}, "equipped": {"weapon_1": "item_que_no_existe", "weapon_2": "", "shield": SWORD_ID}})
	_check(Inventory.get_equipped_id(Inventory.SLOT_WEAPON_1) == "" and Inventory.get_equipped_id(Inventory.SLOT_SHIELD) == "", "un equipo guardado no válido deja el slot vacío")
	Inventory.restore_snapshot(JSON.parse_string(JSON.stringify(snapshot)))

	# --- Entregar un ítem equipado ---
	_check(Inventory.has_item_amount(SWORD_ID, 1), "has_item_amount cuenta la espada equipada")
	_check(Inventory.remove_item(SWORD_ID, 1), "se puede entregar la espada equipada")
	_check(Inventory.get_equipped_id(Inventory.SLOT_WEAPON_1) == "" and Inventory.get_owned_count(SWORD_ID) == 0, "entregarla la desequipa")

	# --- Escudo frontal (120°, 100%) ---
	_player.face_direction(Vector2.RIGHT)
	Input.action_press("block")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(shield.is_blocking, "con escudo equipado se puede bloquear")
	_check(shield.covers_hit(Vector2.LEFT), "cubre un golpe que llega de frente")
	_check(not shield.covers_hit(Vector2.RIGHT), "no cubre un golpe por la espalda")
	var hurtbox: HurtboxComponent = _player.get_node("HurtboxComponent")
	var health_before: int = PlayerStats.health
	hurtbox.take_hit(2, Vector2.LEFT, 0.0, load("res://data/status_effects/poison.tres"))
	_check(PlayerStats.health == health_before, "un golpe frontal no hace daño")
	_check(not PlayerStats.has_status("poison"), "el escudo frontal detiene el veneno")
	hurtbox.take_hit(2, Vector2.RIGHT, 0.0)
	_check(PlayerStats.health == health_before - 2, "un golpe por la espalda hace daño")
	_player.is_invulnerable = false
	PlayerStats.full_heal()

	# --- Escudo de mitad (360°, 50%, sin frenar estados) ---
	Inventory.add_item(HALF_SHIELD_ID)
	Inventory.equip(HALF_SHIELD_ID, Inventory.SLOT_SHIELD)
	await get_tree().physics_frame
	health_before = PlayerStats.health
	hurtbox.take_hit(2, Vector2.RIGHT, 0.0, load("res://data/status_effects/poison.tres"))
	_check(PlayerStats.health == health_before - 1, "el escudo de mitad deja pasar la mitad del daño")
	_check(PlayerStats.has_status("poison"), "el escudo de mitad no detiene el veneno")
	Input.action_release("block")
	_player.is_invulnerable = false
	PlayerStats.cure_all_statuses()
	PlayerStats.full_heal()

	# --- Sin escudo no se bloquea ---
	Inventory.unequip(Inventory.SLOT_SHIELD)
	Input.action_press("block")
	await get_tree().physics_frame
	_check(not shield.is_blocking, "sin escudo no se puede bloquear")
	Input.action_release("block")

	# --- Slot rápido equipa ---
	var slots: QuickSlots = _player.get_node("QuickSlots")
	slots.assign(0, SHIELD_ID)
	slots.use_slot(0)
	_check(Inventory.get_equipped_id(Inventory.SLOT_SHIELD) == SHIELD_ID, "un escudo en un slot rápido se equipa")
	slots.clear_slot(0)

func _reset_state() -> void:
	Input.action_release("block")
	Inventory.restore_snapshot({})
	PlayerStats.cure_all_statuses()
	PlayerStats.full_heal()
	if _player:
		_player.is_invulnerable = false

func _check(condition: bool, description: String) -> void:
	if condition:
		print("  ok - ", description)
	else:
		_failures += 1
		push_error("  FALLA - " + description)
