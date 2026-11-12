extends Node
class_name BattleUnit
## A single combatant (player character OR enemy) in the battle.
##
## CharacterStats holds only the 4 fixed base numbers (health/attack/
## capability/speed). Everything that changes DURING a fight - current HP,
## current energy, whether it's guarding, buffs, stun - lives here on the
## unit instead, since that's runtime state, not a stat. Each unit owns its
## own CharacterStats instance, so HP and the energy bar are fully
## independent per member (rule: individual bars).

signal hp_changed(unit: BattleUnit, new_health: int)
signal energy_changed(unit: BattleUnit, new_energy: int)
signal defeated(unit: BattleUnit)
signal statuses_changed(unit: BattleUnit)
## A boss just reached 60% HP and became immune to Stun (the stage shows a label).
signal stun_immunity_gained(unit: BattleUnit)
signal status_log(text: String) # battle-log lines about statuses (BattleManager forwards them)

const MAX_ENERGY := 5 # energy bar cap, same for every unit

@export var stats: CharacterStats
@export var basic_moves: Array[Move] = []
@export var alteration_moves: Array[Move] = []
@export var is_player_controlled: bool = true

## Enemy-only. If set, this unit ignores Basic/Alteration + energy entirely
## and just cycles through a fixed attack pattern (see EnemyMoveset).
@export var moveset: EnemyMoveset

## Enemy-only: how many moves it makes per turn (bosses = 2).
@export var actions_per_turn: int = 1
## Shown last (in gold) in the enemy list.
@export var is_boss: bool = false
## Training dummy: never attacks (it just stands there and takes hits).
@export var is_dummy: bool = false
var enemy_id: String = ""   # EnemyType file name (encyclopedia); empty for the party
## Training mode: the energy bar is always full and nothing costs energy.
var infinite_energy: bool = false

var current_health: int
var current_energy: int = 0
var is_guarding: bool = false

## Runtime-only state. Units are rebuilt every fight, so these naturally
## start fresh and "last the entire fight".
var move_uses: Dictionary = {}     # Move -> times used this fight
var statuses: Dictionary = {}      # StatusDefs.Kind -> StatusInstance
var is_acting: bool = false        # true while it is this unit's turn (set by BattleManager)
var cooldowns: Dictionary = {}     # Move -> turns until it is usable again

## Upgrade passive for this battle (set by UnitFactory from the equipped upgrade):
## a StatusDefs.Kind (or -1 for none) and its setting (see StatusDefs).
var passive_kind: int = -1
var passive_value: int = 0
var turns_taken: int = 0   # this unit's own turns so far (Beringin counts them)

func _ready() -> void:
	if stats:
		current_health = stats.max_health
	# "Mulai battle dengan efek ...": the passive starts with the battle (0 stacks).
	if passive_kind >= 0:
		add_status(passive_kind, 0, 0, passive_value, false)

## Strike with Sakepeng / Resonance: +1 stack, up to the cap stored in magnitude.
func gain_passive_stack(kind: StatusDefs.Kind) -> bool:
	var st: StatusInstance = statuses.get(kind)
	if st == null or st.stacks >= st.magnitude:
		return false
	st.stacks += 1
	statuses_changed.emit(self)
	return true

func is_alive() -> bool:
	return current_health > 0

## Attack including buffs. Use this instead of stats.attack in combat.
func get_attack() -> int:
	return stats.attack + magnitude_of(StatusDefs.Kind.STRENGTHEN) + _bonus_from_statuses("strength")

## Capability including buffs (Inj-ACB). Use this in combat, not stats.capability.
func get_capability() -> int:
	return stats.capability + _bonus_from_statuses("capability")

func _bonus_from_statuses(which: String) -> int:
	var total := 0
	for kind in statuses:
		var def := StatusDefs.get_def(kind)
		var per: int = 0
		match which:
			"strength":
				per = def.bonus_strength
			"speed":
				per = def.bonus_speed
			"capability":
				per = def.bonus_capability
		total += per * (statuses[kind] as StatusInstance).stacks
	return total

## Applies an ATTACK's damage and returns the actual amount dealt.
## Order: +1 per 2 Gloop stacks (rounded down), then halved by Guard, then halved by Time Dilation.
func take_damage(amount: int) -> int:
	var final_amount := amount
	if final_amount > 0:
		final_amount += stacks_of(StatusDefs.Kind.GLOOP) / 2
	if is_guarding:
		final_amount = int(final_amount * 0.5)
	if has_status(StatusDefs.Kind.TIME_DILATION):
		final_amount = int(final_amount * 0.5)
	return _lose_health(max(0, final_amount))

## Fixed damage that ignores Guard, Gloop and Time Dilation (burning, poison).
func take_true_damage(amount: int) -> int:
	return _lose_health(max(0, amount))

func _lose_health(amount: int) -> int:
	current_health = max(0, current_health - amount)
	hp_changed.emit(self, current_health)
	if current_health == 0:
		_clear_statuses()
		defeated.emit(self)
	elif is_boss:
		_check_boss_phase()
	return amount

## Bosses at 60% HP or less become immune to Stun (and shake off any Stun they have).
func _check_boss_phase() -> void:
	if has_status(StatusDefs.Kind.STUN_IMMUNITY) or current_health * 100 > stats.max_health * 60:
		return
	remove_status(StatusDefs.Kind.STUN)
	add_status(StatusDefs.Kind.STUN_IMMUNITY, 1, 0, 0, false)
	status_log.emit("%s gains Stun Immunity!" % stats.character_name)
	stun_immunity_gained.emit(self)

## Instant KO that ignores Guard (used by execute effects like Condemn).
func kill() -> void:
	current_health = 0
	hp_changed.emit(self, 0)
	_clear_statuses()
	defeated.emit(self)

func heal(amount: int) -> void:
	current_health = min(stats.max_health, current_health + amount)
	hp_changed.emit(self, current_health)

## Rule: filling the bar happens one point per turn taken, up to MAX_ENERGY.
func gain_energy(amount: int = 1) -> void:
	if infinite_energy:
		current_energy = MAX_ENERGY
		return
	current_energy = min(MAX_ENERGY, current_energy + amount)
	energy_changed.emit(self, current_energy)

func spend_energy(amount: int) -> bool:
	if infinite_energy:
		current_energy = MAX_ENERGY
		return true
	if current_energy < amount:
		return false
	current_energy -= amount
	energy_changed.emit(self, current_energy)
	return true

func record_use(move: Move) -> void:
	move_uses[move] = move_uses.get(move, 0) + 1

func uses_left(move: Move) -> int:
	if move.max_uses_per_battle <= 0:
		return -1 # unlimited
	return max(0, move.max_uses_per_battle - move_uses.get(move, 0))

## Energy this unit must pay for a move right now (Sapped = +1 for Alterations).
func energy_cost_for(move: Move) -> int:
	if move.type != Move.Type.ALTERATION:
		return 0
	var cost := move.energy_cost
	if has_status(StatusDefs.Kind.SAPPED):
		cost += 1
	return cost

func can_use_move(move: Move) -> bool:
	if move.max_uses_per_battle > 0 and move_uses.get(move, 0) >= move.max_uses_per_battle:
		return false
	if move.type == Move.Type.ALTERATION:
		return infinite_energy or current_energy >= energy_cost_for(move)
	return true

func reset_turn_flags() -> void:
	is_guarding = false

## Speed stat doubles as a flat dodge chance percentage (0-100),
## Darkest Dungeon-style. Rolled by the ATTACKER's target, not the attacker.
## Speed including buffs (Swift). Dodge chance and Speed-scaling moves use this.
func get_speed() -> int:
	return maxi(0, stats.speed + magnitude_of(StatusDefs.Kind.SWIFT) + _bonus_from_statuses("speed"))

## Energy waiting from an Energized status; called at the start of this unit's turn.
func consume_energized() -> int:
	var st: StatusInstance = statuses.get(StatusDefs.Kind.ENERGIZED)
	if st == null:
		return 0
	var amount := st.magnitude
	remove_status(StatusDefs.Kind.ENERGIZED)
	return amount

## Test hook: the next attacks on this unit are always dodged.
var force_dodge: bool = false

## Dodge chance: (Speed - 15)%, never below 0 and never above 95.
## (Speed 15 or less never dodges; Speed 40 dodges 25% of attacks.)
func dodge_chance() -> float:
	return clampf(float(get_speed() - 15), 0.0, 95.0) / 100.0

func roll_dodge() -> bool:
	if force_dodge:
		return true
	return randf() < dodge_chance()

# ---- status effects -------------------------------------------------------

func has_status(kind: StatusDefs.Kind) -> bool:
	return statuses.has(kind)

func stacks_of(kind: StatusDefs.Kind) -> int:
	var st: StatusInstance = statuses.get(kind)
	return st.stacks if st else 0

func magnitude_of(kind: StatusDefs.Kind) -> int:
	var st: StatusInstance = statuses.get(kind)
	return st.magnitude if st else 0

## Adds stacks (up to the status's max) and refreshes its duration.
## duration 0 = the default from StatusDefs. announce = write a log line.
func add_status(kind: StatusDefs.Kind, stacks_to_add: int = 1, duration: int = 0,
		magnitude: int = 0, announce: bool = true) -> void:
	if not is_alive():
		return
	if kind == StatusDefs.Kind.STUN and has_status(StatusDefs.Kind.STUN_IMMUNITY):
		status_log.emit("%s is immune to Stun!" % stats.character_name)
		return
	var def := StatusDefs.get_def(kind)
	var st: StatusInstance = statuses.get(kind)
	if st == null:
		st = StatusInstance.new()
		st.kind = kind
		statuses[kind] = st
	st.stacks = mini(def.max_stacks, st.stacks + stacks_to_add)
	st.turns_left = duration if duration != 0 else def.duration
	st.magnitude += magnitude
	# A buff given during the owner's own turn should last through the next
	# round, so this turn's end tick skips it once.
	st.fresh = is_acting and def.is_buff

	if announce:
		if def.is_buff:
			status_log.emit("%s gains %s!" % [stats.character_name, def.label])
		elif def.max_stacks > 1:
			status_log.emit("%s is afflicted with %s (x%d)!" % [stats.character_name, def.label, st.stacks])
		else:
			status_log.emit("%s is afflicted with %s!" % [stats.character_name, def.label])

	# Stunning breaks Time Dilation.
	if kind == StatusDefs.Kind.STUN and statuses.has(StatusDefs.Kind.TIME_DILATION):
		remove_status(StatusDefs.Kind.TIME_DILATION)
		status_log.emit("%s's Time Dilation breaks!" % stats.character_name)
	statuses_changed.emit(self)

func remove_status(kind: StatusDefs.Kind) -> void:
	if statuses.erase(kind):
		statuses_changed.emit(self)

## Returns true if this unit loses its turn to Stun (and uses up one stun turn).
## Called at the very start of the unit's turn.
func consume_stun() -> bool:
	var st: StatusInstance = statuses.get(StatusDefs.Kind.STUN)
	if st == null:
		return false
	st.turns_left -= 1
	if st.turns_left <= 0:
		remove_status(StatusDefs.Kind.STUN)
	else:
		statuses_changed.emit(self)
	return true

## End of this unit's turn: damage over time first, then durations count down
## and expired statuses fall off. Call once per turn (stunned turns too).
func tick_end_of_turn() -> void:
	for kind in statuses.keys():
		if not is_alive():
			return
		var st: StatusInstance = statuses.get(kind)
		if st == null:
			continue
		if st.fresh:
			st.fresh = false
			continue
		var def := StatusDefs.get_def(kind)
		if def.dot_per_stack > 0:
			var raw_dot: int = def.dot_per_stack * st.stacks
			if def.max_stack_bonus_damage > 0 and st.stacks >= def.max_stacks:
				raw_dot += def.max_stack_bonus_damage # Fire at max stacks hurts extra
			var dmg := take_true_damage(raw_dot)
			status_log.emit("%s takes %d %s damage!" % [stats.character_name, dmg, def.label])
			if not is_alive():
				return
		if def.ticks_down and st.turns_left != StatusDefs.PERMANENT:
			st.turns_left -= 1
			if st.turns_left <= 0:
				statuses.erase(kind)
				# The crash after an injection wears off (never lethal).
				if def.expire_self_damage_pct > 0.0:
					var crash := Move.round_up(stats.max_health * def.expire_self_damage_pct / 100.0)
					crash = mini(crash, current_health - 1)
					if crash > 0:
						take_true_damage(crash)
						status_log.emit("%s crashes after %s and loses %d HP!" % [stats.character_name, def.label, crash])
	statuses_changed.emit(self)

func _clear_statuses() -> void:
	if not statuses.is_empty():
		statuses.clear()
		statuses_changed.emit(self)

## One line per active status for the "Status" popup, e.g. "Gloop x3  (2 turns)".
func status_lines() -> PackedStringArray:
	var out: PackedStringArray = []
	for kind in statuses:
		out.append(StatusDefs.title(kind, statuses[kind]))
	return out

## [ [title, description], ... ] for the hover popup.
func status_details() -> Array:
	var out: Array = []
	for kind in statuses:
		var st: StatusInstance = statuses[kind]
		out.append([StatusDefs.title(kind, st), StatusDefs.describe(kind, st)])
	return out

## Short HUD text, e.g. "Fire x2  Gloop x3  Strengthen +9". Empty if none.
func status_text() -> String:
	var parts: PackedStringArray = []
	for kind in statuses:
		var st: StatusInstance = statuses[kind]
		var def := StatusDefs.get_def(kind)
		var t := def.label
		if kind in [StatusDefs.Kind.STRENGTHEN, StatusDefs.Kind.SWIFT, StatusDefs.Kind.ENERGIZED]:
			t += " +%d" % st.magnitude
		elif st.stacks > 1:
			t += " x%d" % st.stacks
		parts.append(t)
	return "  ".join(parts)

# ---- move cooldowns (enemies) ---------------------------------------------

func is_ready(move: Move) -> bool:
	return cooldowns.get(move, 0) <= 0

## A cooldown of N means "unavailable for the next N of this unit's turns".
## (N + 1 because the turn it is used on also counts down once.)
func start_cooldown(move: Move) -> void:
	if move.cooldown > 0:
		cooldowns[move] = move.cooldown + 1

## Called once at the end of each of this unit's turns.
func tick_cooldowns() -> void:
	for m in cooldowns.keys():
		cooldowns[m] -= 1
		if cooldowns[m] <= 0:
			cooldowns.erase(m)
