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

var current_health: int
var current_energy: int = 0
var is_guarding: bool = false

## Runtime-only state. Units are rebuilt every fight, so these naturally
## start fresh and "last the entire fight".
var move_uses: Dictionary = {}     # Move -> times used this fight
var statuses: Dictionary = {}      # StatusDefs.Kind -> StatusInstance
var is_acting: bool = false        # true while it is this unit's turn (set by BattleManager)
var cooldowns: Dictionary = {}     # Move -> turns until it is usable again

func _ready() -> void:
	if stats:
		current_health = stats.max_health

func is_alive() -> bool:
	return current_health > 0

## Attack including buffs. Use this instead of stats.attack in combat.
func get_attack() -> int:
	return stats.attack + magnitude_of(StatusDefs.Kind.STRENGTHEN)

## Applies an ATTACK's damage and returns the actual amount dealt.
## Order: +1 per Gloop stack, then halved by Guard, then halved by Time Dilation.
func take_damage(amount: int) -> int:
	var final_amount := amount
	if final_amount > 0:
		final_amount += stacks_of(StatusDefs.Kind.GLOOP)
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
	return amount

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
	current_energy = min(MAX_ENERGY, current_energy + amount)
	energy_changed.emit(self, current_energy)

func spend_energy(amount: int) -> bool:
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
		return current_energy >= energy_cost_for(move)
	return true

func reset_turn_flags() -> void:
	is_guarding = false

## Speed stat doubles as a flat dodge chance percentage (0-100),
## Darkest Dungeon-style. Rolled by the ATTACKER's target, not the attacker.
func roll_dodge() -> bool:
	var chance: float = clamp(stats.speed, 0, 95) / 100.0
	return randf() < chance

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
			var dmg := take_true_damage(def.dot_per_stack * st.stacks)
			status_log.emit("%s takes %d %s damage!" % [stats.character_name, dmg, def.label])
			if not is_alive():
				return
		if def.ticks_down and st.turns_left != StatusDefs.PERMANENT:
			st.turns_left -= 1
			if st.turns_left <= 0:
				statuses.erase(kind)
	statuses_changed.emit(self)

func _clear_statuses() -> void:
	if not statuses.is_empty():
		statuses.clear()
		statuses_changed.emit(self)

## Short HUD text, e.g. "Fire x2  Gloop x3  Strengthen +9". Empty if none.
func status_text() -> String:
	var parts: PackedStringArray = []
	for kind in statuses:
		var st: StatusInstance = statuses[kind]
		var def := StatusDefs.get_def(kind)
		var t := def.label
		if kind == StatusDefs.Kind.STRENGTHEN:
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
