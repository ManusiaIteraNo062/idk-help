extends Resource
class_name Upgrade
## A character upgrade crafted at Admin's workshop (Upgrades tab). Each
## character has a free base entry (tier 0 = no upgrade) and two upgrades.
## Only ONE is active at a time: crafting equips it, and any owned entry can
## be swapped back for free (so equipping the base entry removes the upgrade).
## Upgrades only add stat bonuses; they never rename the Basic attack.

@export var id: String = ""
@export var display_name: String = "Upgrade"
@export var owner_id: String = ""        # Roster character id this belongs to
@export var tier: int = 0                # 0 = no upgrade (base)
@export var cost: int = 0                # Shangri-La Fragments to craft
@export var bonus_health: int = 0
@export var bonus_strength: int = 0
@export var bonus_capability: int = 0
@export var bonus_speed: int = 0
@export_multiline var description: String = ""   # Indonesian flavor text
## Battle passive (2nd and last upgrade only): a StatusDefs.Kind, or -1 for none.
## passive_value: Verlichting = chance %, Sakepeng/Resonance = max stacks, Beringin = every N turns.
@export var passive_kind: int = -1
@export var passive_value: int = 0
@export_multiline var effect_text: String = ""   # Indonesian: what the passive does

static func make(p_id: String, p_name: String, p_owner: String, p_tier: int, p_cost: int,
		hp: int, str_: int, cap: int, spd: int, p_desc: String) -> Upgrade:
	var u := Upgrade.new()
	u.id = p_id
	u.display_name = p_name
	u.owner_id = p_owner
	u.tier = p_tier
	u.cost = p_cost
	u.bonus_health = hp
	u.bonus_strength = str_
	u.bonus_capability = cap
	u.bonus_speed = spd
	u.description = p_desc
	return u

func with_passive(kind: StatusDefs.Kind, value: int, effect: String) -> Upgrade:
	passive_kind = kind
	passive_value = value
	effect_text = effect
	return self

func bonus_text() -> String:
	var t := StatText.bonuses(bonus_health, bonus_strength, bonus_capability, bonus_speed)
	return "tanpa bonus" if t == "" else t
