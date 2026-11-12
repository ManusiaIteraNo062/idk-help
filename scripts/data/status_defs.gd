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

enum Kind { FIRE, POISON, STUN, GLOOP, SAPPED, STRENGTHEN, TIME_DILATION, FLAME_WINGS, ENERGIZED, SWIFT, INJ_CQB, INJ_ACB,
	VERLICHTING, SAKEPENG, BERINGIN, RESONANCE, STUN_IMMUNITY }

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
	# Extra fixed damage at turn end when the status is at its max stacks (Fire: +10).
	var max_stack_bonus_damage: int = 0

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
	var fire := Def.new("Fire", false, 3, 1, 5)              # 5 per stack, gone at turn end
	fire.max_stack_bonus_damage = 10                         # ...and +10 more at 3 stacks
	_defs[Kind.FIRE] = fire
	_defs[Kind.POISON] = Def.new("Poison", false, 2, 2, 3)   # 3 per stack, 2 turns
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
	# Upgrade passives (the 2nd / last upgrade of each character), active the whole mission.
	# `magnitude` carries the setting: Verlichting = chance %, Sakepeng/Resonance = max stacks,
	# Beringin = every N turns.
	_defs[Kind.VERLICHTING] = Def.new("Verlichting", true, 1, PERMANENT)
	var sake := Def.new("Sakepeng", true, 99, PERMANENT)
	sake.bonus_speed = 2     # per stack
	_defs[Kind.SAKEPENG] = sake
	_defs[Kind.BERINGIN] = Def.new("Beringin", true, 1, PERMANENT)
	var reso := Def.new("Resonance", true, 99, PERMANENT)
	reso.bonus_capability = 3 # per stack
	_defs[Kind.RESONANCE] = reso
	# Bosses gain this when their HP reaches 60% (see BattleUnit): Stun no longer works on them.
	_defs[Kind.STUN_IMMUNITY] = Def.new("Stun Immunity", true, 1, PERMANENT)

## The "what does this do" text shown when hovering a status in battle,
## with the real numbers for this unit (stacks, turns left, magnitude).
static func describe(kind: Kind, st: StatusInstance) -> String:
	var def := get_def(kind)
	var turns := st.turns_left
	var turn_text := "Lasts %d turn%s." % [turns, "" if turns == 1 else "s"]
	match kind:
		Kind.FIRE:
			var fire_total: int = def.dot_per_stack * st.stacks
			if st.stacks >= def.max_stacks:
				fire_total += def.max_stack_bonus_damage
			return "Turn End: take %d fixed damage (%d per stack, +%d extra at max stacks). Removed afterwards." % [fire_total, def.dot_per_stack, def.max_stack_bonus_damage]
		Kind.POISON:
			return "Turn End: take %d fixed damage (%d per stack). %s" % [def.dot_per_stack * st.stacks, def.dot_per_stack, turn_text]
		Kind.STUN:
			return "Cannot act on the next turn."
		Kind.GLOOP:
			return "Attacks against this unit deal +%d damage (+1 per 2 stacks). %s" % [st.stacks / 2, turn_text]
		Kind.SAPPED:
			return "Alteration skills cost +1 Energy. Expires at turn end."
		Kind.STRENGTHEN:
			return "+%d Strength until the mission ends." % st.magnitude
		Kind.TIME_DILATION:
			return "Takes 50%% less damage. Removed when stunned. %s" % turn_text
		Kind.FLAME_WINGS:
			return "Attackers gain 1 Fire when they hit this unit. Expires at turn end."
		Kind.ENERGIZED:
			return "Gain %d Energy at the start of the next turn." % st.magnitude
		Kind.SWIFT:
			return "+%d Speed (dodge chance is Speed - 15) until the mission ends." % st.magnitude
		Kind.INJ_CQB:
			return "+5 Speed and +10 Strength. %s Then lose 10%% of max HP." % turn_text
		Kind.INJ_ACB:
			return "+15 Capability. %s Then lose 10%% of max HP." % turn_text
		Kind.VERLICHTING:
			return "Strike: %d%% chance to gain 1 Energized (+1 Energy next turn)." % st.magnitude
		Kind.SAKEPENG:
			return "Each Strike adds a stack (max %d). +2 Speed per stack (now +%d)." % [st.magnitude, 2 * st.stacks]
		Kind.BERINGIN:
			return "Gain 1 Energy at the start of every %d turns." % st.magnitude
		Kind.RESONANCE:
			return "Each Strike adds a stack (max %d). +3 Capability per stack (now +%d)." % [st.magnitude, 3 * st.stacks]
		Kind.STUN_IMMUNITY:
			return "Can no longer be affected by the Stun debuff."
	return ""

## "Gloop x3", "Strengthen +3", "Sakepeng x2/5"... plus turns left where it matters.
static func title(kind: Kind, st: StatusInstance) -> String:
	var def := get_def(kind)
	var t := def.label
	if kind in [Kind.STRENGTHEN, Kind.SWIFT, Kind.ENERGIZED]:
		t += " +%d" % st.magnitude
	elif kind in [Kind.SAKEPENG, Kind.RESONANCE]:
		t += "  %d / %d" % [st.stacks, st.magnitude]
	elif st.stacks > 1:
		t += " x%d" % st.stacks
	if def.ticks_down and st.turns_left != PERMANENT:
		t += "   (%d turn%s)" % [st.turns_left, "" if st.turns_left == 1 else "s"]
	return t
