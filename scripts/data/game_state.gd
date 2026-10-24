extends RefCounted
class_name GameState
## Everything that must survive between missions (and between play
## sessions): fragments, cleared missions, owned/equipped weapons.
## Saved to user://hadirion_save.json after every change that matters.
## To reset progress while testing, call GameState.delete_save() (or delete
## that file from Godot's user data folder: Project > Open User Data Folder).

const SAVE_PATH := "user://hadirion_save.json"
const FINAL_MISSION_ID := "suara_merdu" # clearing this unlocks Training

var fragments: int = 0
var cleared: Dictionary = {}   # mission id (String) -> true
var owned: Dictionary = {}     # weapon id -> true
var equipped: Dictionary = {}  # character id -> weapon id
var seen_lobby_intro: bool = false

# ---- progress -------------------------------------------------------------

func is_cleared(mission_id: StringName) -> bool:
	return cleared.has(String(mission_id))

func mark_cleared(mission_id: StringName) -> void:
	cleared[String(mission_id)] = true

func training_unlocked() -> bool:
	return cleared.has(FINAL_MISSION_ID)

# ---- fragments & gear -----------------------------------------------------

func add_fragments(amount: int) -> void:
	fragments = maxi(0, fragments + amount)

func can_afford(cost: int) -> bool:
	return fragments >= cost

func owns(weapon_id: String) -> bool:
	return owned.has(weapon_id)

func equipped_id(character_id: String) -> String:
	return String(equipped.get(character_id, ""))

func weapon_for(character_id: String) -> Weapon:
	var w := GearLibrary.get_weapon(equipped_id(character_id))
	if w == null:
		var def = Roster.get_def(character_id)
		if def:
			w = GearLibrary.get_weapon(def.base_weapon_id)
	return w

## Spends fragments, adds the weapon, and equips it (it replaces the old one).
func buy_weapon(w: Weapon) -> bool:
	if owns(w.id) or not can_afford(w.cost):
		return false
	fragments -= w.cost
	owned[w.id] = true
	equipped[w.owner_id] = w.id
	return true

func equip(character_id: String, weapon_id: String) -> bool:
	var w := GearLibrary.get_weapon(weapon_id)
	if w == null or w.owner_id != character_id or not owns(weapon_id):
		return false
	equipped[character_id] = weapon_id
	return true

## Every character always owns and (by default) wields their base weapon.
func ensure_defaults() -> void:
	for d in Roster.all():
		owned[d.base_weapon_id] = true
		var current := equipped_id(d.id)
		if current == "" or not owns(current) or GearLibrary.get_weapon(current) == null:
			equipped[d.id] = d.base_weapon_id

# ---- save / load ----------------------------------------------------------

func save() -> void:
	var data := {
		"fragments": fragments,
		"cleared": cleared.keys(),
		"owned": owned.keys(),
		"equipped": equipped,
		"seen_lobby_intro": seen_lobby_intro,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

static func load_or_new() -> GameState:
	var state := GameState.new()
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				state._apply(parsed)
	state.ensure_defaults()
	return state

static func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

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
	seen_lobby_intro = bool(d.get("seen_lobby_intro", false))
