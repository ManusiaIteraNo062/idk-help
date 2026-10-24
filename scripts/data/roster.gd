extends RefCounted
class_name Roster
## The four playable characters from the GDD. Base stats and Alteration
## numbers are PLACEHOLDERS (the GDD gives none). Equipment bonuses from
## GearLibrary are added on top when the team is built (see UnitFactory).

const HELDER_COLOR := Color(0.3, 0.75, 0.8)
const RADIK_COLOR := Color(0.95, 0.6, 0.25)
const DEAN_COLOR := Color(0.35, 0.5, 0.95)
const ADMIN_COLOR := Color(0.7, 0.45, 0.85)

class Def:
	var id: String
	var display_name: String
	var health: int
	var attack: int
	var capability: int
	var speed: int
	var base_weapon_id: String
	var color: Color
	## Each entry: { name, cost, power, target (Move.Target), heal (optional bool) }
	var alterations: Array = []

## Returns an Array of Roster.Def, in party order.
static func all() -> Array:
	var out: Array = []

	var helder := Def.new()
	helder.id = "helder"
	helder.display_name = "Helder"
	helder.health = 100
	helder.attack = 13
	helder.capability = 10
	helder.speed = 8
	helder.base_weapon_id = "helder_baton"
	helder.color = HELDER_COLOR
	helder.alterations = [{"name": "Arc Discharge", "cost": 3, "power": 22, "target": Move.Target.SINGLE_ENEMY}]
	out.append(helder)

	var radik := Def.new()
	radik.id = "radik"
	radik.display_name = "Radik"
	radik.health = 85
	radik.attack = 12
	radik.capability = 7
	radik.speed = 16
	radik.base_weapon_id = "radik_parang"
	radik.color = RADIK_COLOR
	# Placeholder: per the GDD this should scale off Speed (combat code side).
	radik.alterations = [{"name": "Blade Split", "cost": 2, "power": 16, "target": Move.Target.SINGLE_ENEMY}]
	out.append(radik)

	var dean := Def.new()
	dean.id = "dean"
	dean.display_name = "Dean"
	dean.health = 135
	dean.attack = 14
	dean.capability = 4
	dean.speed = 5
	dean.base_weapon_id = "dean_riot"
	dean.color = DEAN_COLOR
	dean.alterations = [{"name": "Riot Sweep", "cost": 2, "power": 18, "target": Move.Target.ALL_ENEMIES}]
	out.append(dean)

	var wyg := Def.new()
	wyg.id = "wyg01"
	wyg.display_name = "WYG-01"
	wyg.health = 90
	wyg.attack = 6
	wyg.capability = 15
	wyg.speed = 7
	wyg.base_weapon_id = "wyg_frame"
	wyg.color = ADMIN_COLOR
	wyg.alterations = [{"name": "Repair Pulse", "cost": 3, "power": 20, "target": Move.Target.SINGLE_ALLY, "heal": true}]
	out.append(wyg)

	return out

static func get_def(character_id: String):
	for d in all():
		if d.id == character_id:
			return d
	return null
