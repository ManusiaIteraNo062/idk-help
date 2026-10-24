extends Resource
class_name Weapon
## A piece of equipment crafted with Shangri-La Fragments at Admin's
## workshop. Each character has one base weapon (tier 0, free, always owned)
## and upgrades that REPLACE it when equipped. Bonuses are simply added to
## the character's CharacterStats when the party is built, so the combat code
## never needs to know weapons exist (it only sees the final numbers).

@export var id: String = ""
@export var display_name: String = "Weapon"
@export var owner_id: String = ""        # Roster character id this belongs to
@export var tier: int = 0                # 0 = the base weapon
@export var cost: int = 0                # Shangri-La Fragments to craft
@export var basic_move_name: String = "Strike" # renames the Basic move
@export var bonus_health: int = 0
@export var bonus_attack: int = 0
@export var bonus_capability: int = 0
@export var bonus_speed: int = 0
@export_multiline var description: String = ""

static func make(p_id: String, p_name: String, p_owner: String, p_tier: int, p_cost: int,
		p_basic_name: String, hp: int, atk: int, cap: int, spd: int, p_desc: String) -> Weapon:
	var w := Weapon.new()
	w.id = p_id
	w.display_name = p_name
	w.owner_id = p_owner
	w.tier = p_tier
	w.cost = p_cost
	w.basic_move_name = p_basic_name
	w.bonus_health = hp
	w.bonus_attack = atk
	w.bonus_capability = cap
	w.bonus_speed = spd
	w.description = p_desc
	return w

func bonus_text() -> String:
	var parts: PackedStringArray = []
	if bonus_health != 0:
		parts.append("%+d HP" % bonus_health)
	if bonus_attack != 0:
		parts.append("%+d ATK" % bonus_attack)
	if bonus_capability != 0:
		parts.append("%+d CAP" % bonus_capability)
	if bonus_speed != 0:
		parts.append("%+d SPD" % bonus_speed)
	return "base weapon" if parts.is_empty() else "  ".join(parts)
