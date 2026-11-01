extends RefCounted
class_name StatusDefs
## The rulebook for every status effect. Tuning a status = editing _build().
##
## Timing rules (all "turns" are the AFFECTED unit's own turns):
##   * Damage-over-time and duration countdown happen at the END of that
##     unit's turn. Duration 1 = "expires at turn end".
##   * Stun does not count down at turn end; it is used up when the unit
##     loses a turn (see BattleUnit.consume_stun).
##   * Buffs a unit gives itself during its own turn skip that turn's end tick
##     (grace), so "grants X next turn" really lasts through the next round.
##   * PERMANENT (-1) lasts the whole fight.

enum Kind { FIRE, POISON, STUN, GLOOP, SAPPED, STRENGTHEN, TIME_DILATION, FLAME_WINGS, ENERGIZED, SWIFT, INJ_CQB, INJ_ACB }

const PERMANENT := -1

class Def:
	var label: String
	var is_buff: bool
	var max_stacks: int
	var duration: int       # default turns (PERMANENT = whole fight)
	var dot_per_stack: int  # fixed damage at turn end, per stack
	var ticks_down: bool    # false = not counted down at turn end (Stun)
	# Flat stat bonuses while active (Admin's injections), per stack.
	var bonus_strength: int = 0
	var bonus_speed: int = 0
	var bonus_capability: int = 0
	# When it runs out on its own, the owner takes this % of max HP as damage
	# (never lethal: it can leave them at 1 HP). 0 = no crash.
	var expire_self_damage_pct: float = 0.0

	func _init(p_label: String, p_buff: bool, p_max: int, p_duration: int,
			p_dot: int = 0, p_ticks: bool = true) -> void:
		label = p_label
		is_buff = p_buff
		max_stacks = p_max
		duration = p_duration
		dot_per_stack = p_dot
		ticks_down = p_ticks

static var _defs: Dictionary = {}

static func get_def(kind: Kind) -> Def:
	if _defs.is_empty():
		_build()
	return _defs[kind]

static func _build() -> void:
	# --- debuffs / damage over time ---
	_defs[Kind.FIRE] = Def.new("Fire", false, 3, 1, 5)       # 5 per stack, gone at turn end
	_defs[Kind.POISON] = Def.new("Poison", false, 2, 2, 2)   # 2 per stack, 2 turns
	_defs[Kind.STUN] = Def.new("Stun", false, 1, 1, 0, false)
	_defs[Kind.GLOOP] = Def.new("Gloop", false, 10, 2)       # +1 damage taken per 2 stacks
	_defs[Kind.SAPPED] = Def.new("Sapped", false, 1, 1)      # Alterations cost +1 energy
	# --- buffs ---
	_defs[Kind.STRENGTHEN] = Def.new("Strengthen", true, 99, PERMANENT) # magnitude = +Attack
	_defs[Kind.TIME_DILATION] = Def.new("Time Dilation", true, 1, 1)    # -50% damage taken
	_defs[Kind.FLAME_WINGS] = Def.new("Flame Wings", true, 1, 1)        # reflects 1 Fire
	# Energized: gives `magnitude` energy at the start of the owner's NEXT turn, then is used up.
	_defs[Kind.ENERGIZED] = Def.new("Energized", true, 1, 1, 0, false)
	# Swift: +Speed (magnitude) for the rest of the mission (Palesa - Stance "Kilau").
	_defs[Kind.SWIFT] = Def.new("Swift", true, 99, PERMANENT)
	# Admin's Special injections: stat boost for 3 turns, then a 10% crash.
	var cqb := Def.new("Inj-CQB", true, 1, 3)
	cqb.bonus_speed = 5
	cqb.bonus_strength = 10
	cqb.expire_self_damage_pct = 10.0
	_defs[Kind.INJ_CQB] = cqb
	var acb := Def.new("Inj-ACB", true, 1, 3)
	acb.bonus_capability = 15
	acb.expire_self_damage_pct = 10.0
	_defs[Kind.INJ_ACB] = acb
