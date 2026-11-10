extends RefCounted
class_name GameState
## Everything that must survive between missions (and between play
## sessions): fragments, cleared missions, upgrades, equipment, learned skills.
## Saved to user://hadirion_save.json after every change that matters.
## To reset progress while testing, call GameState.delete_save() (or delete
## that file from Godot's user data folder: Project > Open User Data Folder).
##
## Old saves keep working: fields that don't exist yet just load as empty.

const SAVE_PATH := "user://hadirion_save.json"
const SAVE_VERSION := 2
const FINAL_MISSION_ID := "suara_merdu" # clearing this unlocks Training

## Where this state is saved (tests point it at a temp file).
var save_path: String = SAVE_PATH

var fragments: int = 0
var cleared: Dictionary = {}        # mission id (String) -> true
var owned: Dictionary = {}          # upgrade id -> true
var equipped: Dictionary = {}       # character id -> the ONE active upgrade id
var gear_owned: Dictionary = {}     # character id -> { equipment id -> true }
var gear_equipped: Dictionary = {}  # character id -> Array of equipment ids (max GearLibrary.SLOTS)
var skills_learned: Dictionary = {} # skill id -> true (only unlockable skills need this)
var enemies_seen: Dictionary = {}   # enemy id (EnemyType file name) -> true; bosses show in the encyclopedia once met
var inventory: Dictionary = {}      # item id -> count carried into battles (max ItemLibrary.MAX_STACK)
var seen_lobby_intro: bool = false

# ---- progress -------------------------------------------------------------

func is_cleared(mission_id: StringName) -> bool:
	return cleared.has(String(mission_id))

func mark_cleared(mission_id: StringName) -> void:
	cleared[String(mission_id)] = true

func training_unlocked() -> bool:
	return cleared.has(FINAL_MISSION_ID)

# ---- fragments ------------------------------------------------------------

func add_fragments(amount: int) -> void:
	fragments = maxi(0, fragments + amount)

func can_afford(cost: int) -> bool:
	return fragments >= cost

# ---- upgrades (one active per character) ---------------------------------------

func owns(upgrade_id: String) -> bool:
	return owned.has(upgrade_id)

func equipped_id(character_id: String) -> String:
	return String(equipped.get(character_id, ""))

func upgrade_for(character_id: String) -> Upgrade:
	var u := GearLibrary.get_upgrade(equipped_id(character_id))
	if u == null:
		var def = Roster.get_def(character_id)
		if def:
			u = GearLibrary.get_upgrade(def.base_upgrade_id)
	return u

## Tier 1 is open from the start; tier 2 needs tier 1 to be owned first.
func upgrade_unlocked(u: Upgrade) -> bool:
	var need := GearLibrary.previous_upgrade(u)
	return need == null or owns(need.id)

## Spends fragments, adds the upgrade, and equips it (it replaces the old one).
func buy_upgrade(u: Upgrade) -> bool:
	if owns(u.id) or not upgrade_unlocked(u) or not can_afford(u.cost):
		return false
	fragments -= u.cost
	owned[u.id] = true
	equipped[u.owner_id] = u.id
	return true

func equip_upgrade(character_id: String, upgrade_id: String) -> bool:
	var u := GearLibrary.get_upgrade(upgrade_id)
	if u == null or u.owner_id != character_id or not owns(upgrade_id):
		return false
	equipped[character_id] = upgrade_id
	return true

# ---- equipment (each character owns their own copy of each item) -------------

func owns_gear(character_id: String, item_id: String) -> bool:
	var mine: Dictionary = gear_owned.get(character_id, {})
	return mine.has(item_id)

func gear_ids(character_id: String) -> Array:
	return gear_equipped.get(character_id, [])

func is_gear_equipped(character_id: String, item_id: String) -> bool:
	return item_id in gear_ids(character_id)

func gear_slots_used(character_id: String) -> int:
	return gear_ids(character_id).size()

func has_free_slot(character_id: String) -> bool:
	return gear_slots_used(character_id) < GearLibrary.SLOTS

## Crafts one copy for this character (50 Fragments, one of each, no stacking).
## It is worn immediately if a slot is free.
func buy_gear(character_id: String, item: EquipmentItem) -> bool:
	if owns_gear(character_id, item.id) or not can_afford(item.cost):
		return false
	fragments -= item.cost
	var mine: Dictionary = gear_owned.get(character_id, {})
	mine[item.id] = true
	gear_owned[character_id] = mine
	if has_free_slot(character_id):
		_set_gear(character_id, item.id, true)
	return true

func equip_gear(character_id: String, item_id: String) -> bool:
	if not owns_gear(character_id, item_id) or is_gear_equipped(character_id, item_id) or not has_free_slot(character_id):
		return false
	_set_gear(character_id, item_id, true)
	return true

func unequip_gear(character_id: String, item_id: String) -> bool:
	if not is_gear_equipped(character_id, item_id):
		return false
	_set_gear(character_id, item_id, false)
	return true

func _set_gear(character_id: String, item_id: String, on: bool) -> void:
	var list: Array = gear_ids(character_id).duplicate()
	if on:
		list.append(item_id)
	else:
		list.erase(item_id)
	gear_equipped[character_id] = list

# ---- skills ---------------------------------------------------------------

func knows_skill(skill: Skill) -> bool:
	return not skill.unlockable or skills_learned.has(skill.id)

func learn_skill(skill: Skill) -> bool:
	if knows_skill(skill) or not can_afford(skill.cost):
		return false
	fragments -= skill.cost
	skills_learned[skill.id] = true
	return true

# ---- enemy encyclopedia ----------------------------------------------------

func has_met(enemy_id: String) -> bool:
	return enemies_seen.has(enemy_id)

## Returns true the first time this enemy is seen.
func mark_enemy_seen(enemy_id: String) -> bool:
	if enemy_id == "" or enemies_seen.has(enemy_id):
		return false
	enemies_seen[enemy_id] = true
	return true

# ---- items (Preparation) --------------------------------------------------

func item_count(item_id: String) -> int:
	return int(inventory.get(item_id, 0))

func can_carry_more(item_id: String) -> bool:
	return item_count(item_id) < ItemLibrary.MAX_STACK

## Crafts one item (price depends on the item). Stops at ItemLibrary.MAX_STACK.
func buy_item(item: Item) -> bool:
	if not can_carry_more(item.id) or not can_afford(item.cost):
		return false
	fragments -= item.cost
	inventory[item.id] = item_count(item.id) + 1
	return true

# ---- final stats ----------------------------------------------------------

## Base stats + active upgrade + worn equipment, as a Dictionary:
## { health, attack (= Strength), capability, speed }. Speed can't go below 0
## and HP can't go below 1.
func stats_for(character_id: String) -> Dictionary:
	var d = Roster.get_def(character_id)
	var hp: int = d.health
	var atk: int = d.attack
	var cap: int = d.capability
	var spd: int = d.speed
	var u := upgrade_for(character_id)
	if u:
		hp += u.bonus_health
		atk += u.bonus_strength
		cap += u.bonus_capability
		spd += u.bonus_speed
	for item_id in gear_ids(character_id):
		var e := GearLibrary.get_equipment(item_id)
		if e:
			hp += e.bonus_health
			atk += e.bonus_strength
			cap += e.bonus_capability
			spd += e.bonus_speed
	return {"health": maxi(1, hp), "attack": atk, "capability": cap, "speed": maxi(0, spd)}

## Every character always owns and (by default) wields their base entry.
func ensure_defaults() -> void:
	for d in Roster.all():
		owned[d.base_upgrade_id] = true
		var current := equipped_id(d.id)
		if current == "" or not owns(current) or GearLibrary.get_upgrade(current) == null:
			equipped[d.id] = d.base_upgrade_id
		# Drop unknown / duplicate / excess equipment from older or hand-edited saves.
		var cleaned: Array = []
		for item_id in gear_ids(d.id):
			if owns_gear(d.id, item_id) and GearLibrary.get_equipment(item_id) != null \
					and not item_id in cleaned and cleaned.size() < GearLibrary.SLOTS:
				cleaned.append(item_id)
		gear_equipped[d.id] = cleaned

# ---- save / load ----------------------------------------------------------

func save(path: String = "") -> void:
	if path == "":
		path = save_path
	var gear_owned_out := {}
	for k in gear_owned:
		gear_owned_out[k] = gear_owned[k].keys()
	var data := {
		"version": SAVE_VERSION,
		"fragments": fragments,
		"cleared": cleared.keys(),
		"owned": owned.keys(),
		"equipped": equipped,
		"gear_owned": gear_owned_out,
		"gear_equipped": gear_equipped,
		"skills_learned": skills_learned.keys(),
		"inventory": inventory,
		"enemies_seen": enemies_seen.keys(),
		"seen_lobby_intro": seen_lobby_intro,
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

static func load_or_new(path: String = SAVE_PATH) -> GameState:
	var state := GameState.new()
	state.save_path = path
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				state._apply(parsed)
	state.ensure_defaults()
	return state

static func save_exists(path: String = SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)

static func delete_save(path: String = SAVE_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _apply(d: Dictionary) -> void:
	fragments = int(d.get("fragments", 0))
	for id in d.get("cleared", []):
		cleared[str(id)] = true
	for id in d.get("owned", []):
		owned[str(id)] = true
	var eq = d.get("equipped", {})
	if eq is Dictionary:
		for k in eq:
			equipped[str(k)] = str(eq[k])
	var go = d.get("gear_owned", {})
	if go is Dictionary:
		for k in go:
			var mine := {}
			for id in go[k]:
				mine[str(id)] = true
			gear_owned[str(k)] = mine
	var ge = d.get("gear_equipped", {})
	if ge is Dictionary:
		for k in ge:
			var list: Array = []
			for id in ge[k]:
				list.append(str(id))
			gear_equipped[str(k)] = list
	for id in d.get("skills_learned", []):
		skills_learned[str(id)] = true
	for id in d.get("enemies_seen", []):
		enemies_seen[str(id)] = true
	var inv = d.get("inventory", {})
	if inv is Dictionary:
		for k in inv:
			inventory[str(k)] = clampi(int(inv[k]), 0, ItemLibrary.MAX_STACK)
	seen_lobby_intro = bool(d.get("seen_lobby_intro", false))
