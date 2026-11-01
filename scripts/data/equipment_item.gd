extends Resource
class_name EquipmentItem
## A piece of equipment crafted in the workshop (Equipment tab). Every
## character can craft the SAME list, but each character crafts and owns their
## own copy (one of each, no stacking) and can wear up to GearLibrary.SLOTS.

@export var id: String = ""
@export var display_name: String = "Equipment"
@export var cost: int = 50
@export var bonus_health: int = 0
@export var bonus_strength: int = 0
@export var bonus_capability: int = 0
@export var bonus_speed: int = 0
@export_multiline var description: String = ""   # Indonesian flavor text

static func make(p_id: String, p_name: String, hp: int, str_: int, cap: int, spd: int, p_desc: String) -> EquipmentItem:
	var e := EquipmentItem.new()
	e.id = p_id
	e.display_name = p_name
	e.bonus_health = hp
	e.bonus_strength = str_
	e.bonus_capability = cap
	e.bonus_speed = spd
	e.description = p_desc
	return e

func bonus_text() -> String:
	return StatText.bonuses(bonus_health, bonus_strength, bonus_capability, bonus_speed)
