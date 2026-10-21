extends Node2D

## Equipment and shield test (design/Sistema_Armas_y_Escudo.md).
## When the scene opens it runs automatic checks (PASS/FAIL in the console and on screen),
## leaves equipment empty, and the scene is ready to test by hand with the pickups.

const SWORD_ID: String = "wooden_sword"
const CLUB_ID: String = "test_heavy_club"
const SHIELD_ID: String = "test_wooden_shield"
const HALF_SHIELD_ID: String = "test_half_shield"

## Test items outside data/items: registered in ItemDatabase when the scene opens.
@export var test_items: Array[Resource] = []

@onready var _player: CharacterBody2D = $Player
@onready var _result_label: Label = %ResultLabel

var _failures: int = 0

func _ready() -> void:
	for item: Resource in test_items:
		ItemDatabase.register_item(item as ItemData)
	# Wait for the player to finish its _ready and enter the physics tree
	await get_tree().process_frame
	await get_tree().physics_frame
	await _run_checks()
	_reset_state()
	# For the manual test: like a new game (basic weapon equipped, no shield)
	Inventory.restore_snapshot({})
	var summary: String = "PASS: equipment and shield" if _failures == 0 else "FAIL: %d checks failed" % _failures
	print(summary)
	_result_label.text = summary

func _run_checks() -> void:
	# --- New game: basic weapon equipped, no shield ---
	Inventory.restore_snapshot({})
	_check(Inventory.get_equipped_id(Inventory.SLOT_WEAPON_1) == Inventory.STARTING_WEAPON_ID, "a new game starts with the basic weapon equipped")
	_check(Inventory.get_equipped_id(Inventory.SLOT_SHIELD) == "", "a new game starts without a shield")
	_check(Inventory.get_item_count(Inventory.STARTING_WEAPON_ID) == 0, "the equipped basic weapon does not appear in the list")
	Inventory.restore_snapshot({SWORD_ID: 1, CLUB_ID: 1})
	_check(Inventory.get_owned_count(SWORD_ID) == 1, "an old save with the sword does not duplicate it when equipped")
	_reset_state()
	var weapon: WeaponComponent = _player.get_node("WeaponComponent")
	var shield: ShieldComponent = _player.get_node("ShieldComponent")

	# --- Equip and unequip ---
	Inventory.add_item(SWORD_ID)
	Inventory.add_item(CLUB_ID)
	Inventory.add_item(SHIELD_ID)
	_check(Inventory.equip(SWORD_ID, Inventory.SLOT_WEAPON_1), "equips the sword in Weapon 1")
	_check(Inventory.get_item_count(SWORD_ID) == 0, "the equipped sword leaves the list")
	_check(Inventory.get_owned_count(SWORD_ID) == 1, "item.wooden_sword still counts the sword")
	_check(weapon.weapon == Inventory.get_equipped(Inventory.SLOT_WEAPON_1).equipment, "the player uses the active weapon")
	_check(not Inventory.equip(SHIELD_ID, Inventory.SLOT_WEAPON_2), "a shield does not fit in a weapon slot")
	_check(not Inventory.equip(SWORD_ID, Inventory.SLOT_SHIELD), "a weapon does not fit in the shield slot")
	_check(Inventory.equip(CLUB_ID, Inventory.SLOT_WEAPON_1), "replaces the weapon in the slot")
	_check(Inventory.get_item_count(SWORD_ID) == 1, "the replaced weapon returns to the inventory")
	_check(weapon.get_damage(PlayerStats.get_strength()) == PlayerStats.get_strength() + 3, "damage = strength + weapon damage")
	_check(Inventory.equip(SWORD_ID, Inventory.SLOT_WEAPON_2), "equips the sword in Weapon 2")

	# --- Toggle and swap ---
	Inventory.switch_active_weapon()
	_check(Inventory.active_weapon == Inventory.SLOT_WEAPON_2, "toggles the active weapon")
	_check(GameVariables.get_var("equip.active") == SWORD_ID, "equip.active reflects the active weapon")
	_check(weapon.weapon == ItemDatabase.get_item(SWORD_ID).equipment, "the player switches to the active weapon")
	_check(Inventory.equip(SWORD_ID, Inventory.SLOT_WEAPON_1), "move a weapon to the other slot")
	_check(Inventory.get_equipped_id(Inventory.SLOT_WEAPON_2) == CLUB_ID, "the two weapon slots swap")
	Inventory.unequip(Inventory.SLOT_WEAPON_2)
	_check(Inventory.get_item_count(CLUB_ID) == 1 and Inventory.get_equipped_id(Inventory.SLOT_WEAPON_2) == "", "unequipping returns the weapon")
	_check(weapon.weapon == null, "with the active slot empty the strike is the base one")

	# --- Saving ---
	_check(Inventory.equip(SHIELD_ID, Inventory.SLOT_SHIELD), "equips the shield")
	_check(GameVariables.get_var("equip.shield") == SHIELD_ID, "equip.shield reflects the shield")
	var snapshot: Dictionary = Inventory.create_snapshot()
	Inventory.restore_snapshot({CLUB_ID: 2})
	_check(Inventory.get_item_count(CLUB_ID) == 2 and Inventory.get_equipped_id(Inventory.SLOT_SHIELD) == "", "reads the old inventory format")
	Inventory.restore_snapshot(JSON.parse_string(JSON.stringify(snapshot)))
	_check(Inventory.get_equipped_id(Inventory.SLOT_WEAPON_1) == SWORD_ID and Inventory.get_equipped_id(Inventory.SLOT_SHIELD) == SHIELD_ID, "restores equipment after a JSON round-trip")
	_check(Inventory.active_weapon == Inventory.SLOT_WEAPON_2, "restores the active weapon")
	_check(shield.shield_data == ItemDatabase.get_item(SHIELD_ID).equipment, "the player receives the restored shield")

	Inventory.restore_snapshot({"items": {}, "equipped": {"weapon_1": "item_que_no_existe", "weapon_2": "", "shield": SWORD_ID}})
	_check(Inventory.get_equipped_id(Inventory.SLOT_WEAPON_1) == "" and Inventory.get_equipped_id(Inventory.SLOT_SHIELD) == "", "invalid saved equipment leaves the slot empty")
	Inventory.restore_snapshot(JSON.parse_string(JSON.stringify(snapshot)))

	# --- Hand over an equipped item ---
	_check(Inventory.has_item_amount(SWORD_ID, 1), "has_item_amount counts the equipped sword")
	_check(Inventory.remove_item(SWORD_ID, 1), "the equipped sword can be handed over")
	_check(Inventory.get_equipped_id(Inventory.SLOT_WEAPON_1) == "" and Inventory.get_owned_count(SWORD_ID) == 0, "handing it over unequips it")

	# --- Front shield (120°, 100%) ---
	_player.face_direction(Vector2.RIGHT)
	Input.action_press("block")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(shield.is_blocking, "with a shield equipped you can block")
	_check(shield.covers_hit(Vector2.LEFT), "covers a hit coming from the front")
	_check(not shield.covers_hit(Vector2.RIGHT), "does not cover a hit from behind")
	var hurtbox: HurtboxComponent = _player.get_node("HurtboxComponent")
	var health_before: int = PlayerStats.health
	hurtbox.take_hit(2, Vector2.LEFT, 0.0, load("res://data/status_effects/poison.tres"))
	_check(PlayerStats.health == health_before, "a front hit does no damage")
	_check(not PlayerStats.has_status("poison"), "the front shield stops poison")
	hurtbox.take_hit(2, Vector2.RIGHT, 0.0)
	_check(PlayerStats.health == health_before - 2, "a hit from behind does damage")
	_player.is_invulnerable = false
	PlayerStats.full_heal()

	# --- Half shield (360°, 50%, does not stop statuses) ---
	Inventory.add_item(HALF_SHIELD_ID)
	Inventory.equip(HALF_SHIELD_ID, Inventory.SLOT_SHIELD)
	await get_tree().physics_frame
	health_before = PlayerStats.health
	hurtbox.take_hit(2, Vector2.RIGHT, 0.0, load("res://data/status_effects/poison.tres"))
	_check(PlayerStats.health == health_before - 1, "the half shield lets half the damage through")
	_check(PlayerStats.has_status("poison"), "the half shield does not stop poison")
	Input.action_release("block")
	_player.is_invulnerable = false
	PlayerStats.cure_all_statuses()
	PlayerStats.full_heal()

	# --- No shield means no blocking ---
	Inventory.unequip(Inventory.SLOT_SHIELD)
	Input.action_press("block")
	await get_tree().physics_frame
	_check(not shield.is_blocking, "without a shield you cannot block")
	Input.action_release("block")

	# --- Quick slot equips ---
	var slots: QuickSlots = _player.get_node("QuickSlots")
	slots.assign(0, SHIELD_ID)
	slots.use_slot(0)
	_check(Inventory.get_equipped_id(Inventory.SLOT_SHIELD) == SHIELD_ID, "a shield in a quick slot gets equipped")
	slots.clear_slot(0)

	# --- Quick slot: swap with equipped ---
	_reset_state()
	Inventory.add_item(SWORD_ID)
	Inventory.add_item("iron_sword")
	Inventory.equip(SWORD_ID, Inventory.active_weapon)
	slots.assign(0, "iron_sword")
	slots.use_slot(0)
	_check(Inventory.get_equipped_id(Inventory.active_weapon) == "iron_sword", "the quick slot equips the iron sword")
	_check(slots.get_slot(0) == SWORD_ID, "the sword you had moves to the quick slot")
	slots.use_slot(0)
	_check(Inventory.get_equipped_id(Inventory.active_weapon) == SWORD_ID and slots.get_slot(0) == "iron_sword", "using it again swaps them back")
	Inventory.unequip(Inventory.active_weapon)
	slots.use_slot(0)
	_check(Inventory.get_equipped_id(Inventory.active_weapon) == "iron_sword" and slots.get_slot(0) == "", "with no weapon equipped the slot is left empty")
	Inventory.add_item("wooden_shield")
	Inventory.add_item("iron_shield")
	Inventory.equip("wooden_shield", Inventory.SLOT_SHIELD)
	slots.assign(1, "iron_shield")
	slots.use_slot(1)
	_check(Inventory.get_equipped_id(Inventory.SLOT_SHIELD) == "iron_shield" and slots.get_slot(1) == "wooden_shield", "shields also swap")

	# --- Equipment HUD ---
	var hud: EquipmentHud = _player.get_node("PlayerHUD/EquipmentHud")
	_check(hud._weapon_icon.texture == Inventory.get_active_weapon().icon, "the HUD shows the active weapon")
	_check(hud._shield_icon.texture == ItemDatabase.get_item("iron_shield").icon, "the HUD shows the equipped shield")
	Inventory.unequip(Inventory.SLOT_SHIELD)
	_check(hud._shield_icon.texture == null and hud._shield_placeholder.visible, "without a shield the HUD shows the empty slot")

	# --- Quick slot: consumable that runs out ---
	Inventory.add_item("red_potion", 2)
	slots.assign(2, "red_potion")
	slots.use_slot(2)
	_check(slots.get_slot(2) == "red_potion" and Inventory.get_item_count("red_potion") == 1, "consumes a potion and the slot stays")
	slots.use_slot(2)
	_check(slots.get_slot(2) == "", "when the last potion is used up the slot empties")
	for i: int in QuickSlots.SLOT_COUNT:
		slots.clear_slot(i)

## Empty inventory and equipment (without the basic weapon), so each block starts the same.
func _reset_state() -> void:
	Input.action_release("block")
	Inventory.restore_snapshot({"items": {}, "equipped": {}})
	PlayerStats.cure_all_statuses()
	PlayerStats.full_heal()
	if _player:
		_player.is_invulnerable = false

func _check(condition: bool, description: String) -> void:
	if condition:
		print("  ok - ", description)
	else:
		_failures += 1
		push_error("  FAIL - " + description)
