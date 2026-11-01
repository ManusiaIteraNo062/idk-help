extends Node
class_name BattleManager
## Orchestrates the whole fight.
##
## Turn order (rule 1): each round, every alive PLAYER unit acts in order,
## then every alive ENEMY unit acts in order. No interleaving by speed -
## Speed is used only as dodge chance (see CharacterStats), not turn order.
## Crit chance is a fixed global rate (CRIT_CHANCE below), same for
## allies and enemies - it is not a per-unit stat.
##
## Player turns are driven by an `await` on a signal: nothing happens until
## the UI (or any other input source) calls submit_player_action(). This
## satisfies rule 4 - the player explicitly picks every action for every
## member, one at a time.

signal battle_log(text: String)
signal round_started(round_number: int)
signal player_turn_started(unit: BattleUnit, available_actions: Dictionary)
signal enemy_turn_started(unit: BattleUnit)
signal action_resolved(unit: BattleUnit, description: String)
signal battle_ended(player_won: bool)
## "Name used" strip: who did what ("Condemn", "Guard", an item name...).
signal action_announced(user: BattleUnit, action_name: String)
## An attack missed. Emitted for EVERY attack, damaging or not (the UI shows "Dodge!").
signal attack_dodged(target: BattleUnit, attacker: BattleUnit)
signal wave_started(units: Array) # a new group of enemies has just appeared (waves 2+)

@export var player_team: Array[BattleUnit] = [] # up to 4 (rule 3)
@export var enemy_team: Array[BattleUnit] = []

var party_inventory: Dictionary = {} # Item -> int quantity

## Multi-wave battles: enemy_team is wave 1; wave_factory(i) builds wave i
## (0-based) as an Array of BattleUnit. The party's HP, energy, items and
## statuses carry over between waves. battle_ended fires after the LAST wave.
var wave_count: int = 1
var wave_factory: Callable
var current_wave: int = 1 # 1-based, for display

const CRIT_CHANCE := 1.0 / 14.0 # fixed for BOTH allies and enemies
const CRIT_MULTIPLIER := 1.5

## Training mode: infinite energy for the party, set before start_battle().
## The battle only ends when abort_battle() is called (or someone falls).
var training: bool = false

## Instance copy so tests can force crits off (set to 0.0).
var crit_chance: float = CRIT_CHANCE

var _round_number: int = 0
var _pending_action: Dictionary = {}
var _waiting_for_player: bool = false
var _stopped: bool = false # set by abort_battle(): the loop stops at its next step

signal _player_action_submitted

func add_item(item: Item, quantity: int = 1) -> void:
	party_inventory[item] = party_inventory.get(item, 0) + quantity

func start_battle() -> void:
	_round_number = 0
	if training:
		for u in player_team:
			u.infinite_energy = true
			u.current_energy = BattleUnit.MAX_ENERGY
			u.energy_changed.emit(u, u.current_energy)
	# Statuses write their own log lines (applied / damage / broken).
	for u in player_team + enemy_team:
		_hook_unit(u)
	if wave_count > 1:
		battle_log.emit("=== Wave 1 of %d ===" % wave_count)
	_run_battle_loop()

func _hook_unit(u: BattleUnit) -> void:
	u.status_log.connect(func(text: String): battle_log.emit(text))

func _run_battle_loop() -> void:
	while true:
		_round_number += 1
		round_started.emit(_round_number)
		battle_log.emit("--- Round %d ---" % _round_number)

		for unit in player_team:
			unit.reset_turn_flags()
		for unit in enemy_team:
			unit.reset_turn_flags()

		# Player team moves first.
		for unit in player_team:
			if not unit.is_alive():
				continue
			await _process_player_turn(unit)
			if _stopped or await _check_battle_over():
				return

		# Enemy team moves second.
		for unit in enemy_team:
			if not unit.is_alive():
				continue
			_process_enemy_turn(unit)
			if _stopped or await _check_battle_over():
				return

## Returns what a unit is currently allowed to pick from. The UI should
## build its menu straight from this rather than assuming moves are usable.
func get_available_actions(unit: BattleUnit) -> Dictionary:
	return {
		"basic": unit.basic_moves,
		"alteration": unit.alteration_moves.filter(func(m): return unit.can_use_move(m)),
		"locked_alteration": unit.alteration_moves.filter(func(m): return not unit.can_use_move(m)),
		"items": party_inventory.keys().filter(func(i): return party_inventory[i] > 0),
	}

## Returns true if the unit loses its turn to a stun (and uses up one stun
## turn). Called BEFORE anything else in a turn, so a stunned enemy's
## pattern does not advance on the lost turn.
func _consume_stun(unit: BattleUnit) -> bool:
	if not unit.consume_stun():
		return false
	battle_log.emit("%s is stunned and loses the turn!" % unit.stats.character_name)
	return true

## End of a unit's turn: damage over time, then status durations count down.
func _finish_turn(unit: BattleUnit) -> void:
	unit.is_acting = false
	unit.tick_end_of_turn()
	unit.tick_cooldowns()

## Energy promised by an Energized status (Palesa - Stance "Heroik") arrives at
## the very start of the unit's next turn.
func _grant_stored_energy(unit: BattleUnit) -> void:
	var stored := unit.consume_energized()
	if stored > 0:
		unit.gain_energy(stored)
		battle_log.emit("%s gains %d Energy!" % [unit.stats.character_name, stored])

func _process_player_turn(unit: BattleUnit) -> void:
	unit.is_acting = true
	_grant_stored_energy(unit)
	if _consume_stun(unit):
		_finish_turn(unit)
		return
	player_turn_started.emit(unit, get_available_actions(unit))
	_waiting_for_player = true
	await _player_action_submitted
	_waiting_for_player = false
	if _stopped:
		return
	_execute_action(unit, _pending_action)
	_finish_turn(unit)

## Called by the UI (or any input layer) once the player has fully chosen
## an action + target(s) for the unit whose turn it currently is.
## action_data shape: { type: "basic"|"alteration"|"item"|"guard",
##                       move: Move (optional), item: Item (optional),
##                       targets: Array[BattleUnit] }
func submit_player_action(action_data: Dictionary) -> void:
	if not _waiting_for_player:
		return
	_pending_action = action_data
	_player_action_submitted.emit()

## Leaves a training session (counts as a "win" so the flow just carries on).
func abort_battle() -> void:
	if _stopped:
		return
	_stopped = true
	battle_log.emit("Training ended.")
	battle_ended.emit(true)
	if _waiting_for_player: # release the loop if it is waiting for a choice
		_pending_action = {}
		_player_action_submitted.emit()

func _process_enemy_turn(unit: BattleUnit) -> void:
	unit.is_acting = true
	if unit.is_dummy:
		_finish_turn(unit) # a dummy only stands there (burning still ticks)
		return
	if _consume_stun(unit):
		_finish_turn(unit)
		return
	enemy_turn_started.emit(unit)
	# Mobs act once per turn, bosses twice (BattleUnit.actions_per_turn).
	for i in range(maxi(1, unit.actions_per_turn)):
		if not unit.is_alive():
			break
		var action_data := _choose_enemy_action(unit)
		if action_data.is_empty():
			break
		_execute_action(unit, action_data)
	_finish_turn(unit)

## Enemy action selection.
## Priority 1: a fixed EnemyMoveset (rule addition) - no energy, no
## Basic/Alteration split, just "what's next in the pattern".
## Priority 2 (fallback, only used if an enemy has no moveset assigned):
## the old lightweight random AI, kept around in case you want a
## non-pattern "wild" enemy type too.
func _choose_enemy_action(unit: BattleUnit) -> Dictionary:
	var alive_targets: Array = player_team.filter(func(u): return u.is_alive())
	if alive_targets.is_empty():
		return {}

	if unit.moveset and not unit.moveset.moves.is_empty():
		var move: Move = unit.moveset.choose(unit)
		if move == null:
			return {}
		return {"type": "enemy_move", "move": move, "targets": _resolve_targets(move, alive_targets)}

	var usable_alterations: Array = unit.alteration_moves.filter(func(m): return unit.can_use_move(m))
	if usable_alterations.size() > 0 and randf() < 0.35:
		var move: Move = usable_alterations[randi() % usable_alterations.size()]
		return {"type": "alteration", "move": move, "targets": [alive_targets[randi() % alive_targets.size()]]}

	if unit.basic_moves.size() > 0:
		var move: Move = unit.basic_moves[randi() % unit.basic_moves.size()]
		return {"type": "basic", "move": move, "targets": [alive_targets[randi() % alive_targets.size()]]}

	return {"type": "guard", "targets": []}

## Shared target resolution for a move against a pool of valid candidates
## (used by fixed-pattern enemies; single target is random among the pool,
## ALL_* target types hit everyone in the pool).
func _resolve_targets(move: Move, candidates: Array) -> Array:
	if candidates.is_empty():
		return []
	if move.target_type == Move.Target.ALL_ENEMIES or move.target_type == Move.Target.ALL_ALLIES:
		return candidates.duplicate()
	return [candidates[randi() % candidates.size()]]

func _execute_action(unit: BattleUnit, action_data: Dictionary) -> void:
	if action_data.is_empty():
		return
	var type: String = action_data.get("type", "guard")
	var targets: Array = action_data.get("targets", [])

	# Tell the UI what was used (shown in the top-left "Name used" strip).
	var shown: String = "Guard"
	if action_data.has("move"):
		shown = action_data["move"].move_name
	elif action_data.has("item"):
		shown = action_data["item"].item_name
	action_announced.emit(unit, shown)

	match type:
		"enemy_move":
			# Fixed-pattern enemy move: no Basic/Alteration split, no energy
			# cost, no energy gain. The pattern itself is the only limiter.
			unit.start_cooldown(action_data["move"])
			_resolve_move(unit, action_data["move"], targets)
		"basic":
			# Basic moves are free, and using one still fills the bar (rule 6).
			_resolve_move(unit, action_data["move"], targets)
			unit.gain_energy(1)
		"alteration":
			var move: Move = action_data["move"]
			if unit.can_use_move(move) and unit.spend_energy(unit.energy_cost_for(move)):
				unit.record_use(move)
				_resolve_move(unit, move, targets)
			else:
				battle_log.emit("%s can't use %s right now!" % [unit.stats.character_name, move.move_name])
		"item":
			# Using an item still spends the unit's whole turn (rule 8),
			# and that turn still fills their own energy bar.
			_resolve_item(unit, action_data["item"], targets)
			unit.gain_energy(1)
		"guard":
			# Guarding halves damage and grants an Energized effect: +1 Energy
			# at the start of the unit's next turn.
			unit.is_guarding = true
			unit.add_status(StatusDefs.Kind.ENERGIZED, 1, 0, 1, false)
			battle_log.emit("%s guards." % unit.stats.character_name)

	action_resolved.emit(unit, "%s's turn resolved." % unit.stats.character_name)

func _resolve_move(user: BattleUnit, move: Move, targets: Array) -> void:
	# Effects on the user, once per use: granted statuses (Time Dilation, Flame
	# Wings, Strengthen, Energized...) and the guarding stance.
	_apply_statuses(user, move.grants_self, user)
	if move.self_guard:
		user.is_guarding = true

	# Old-style self-buff (battle_demo's Strengthen): no dodge, no damage.
	if move.buff_attack_flat != 0 or move.buff_attack_cap_mult != 0.0:
		var gain: int = move.buff_attack_flat + Move.round_up(user.get_capability() * move.buff_attack_cap_mult)
		user.add_status(StatusDefs.Kind.STRENGTHEN, 1, 0, gain, false)
		battle_log.emit("%s uses %s, gaining %d Attack!" % [
			user.stats.character_name, move.move_name, gain
		])
		return

	# Pure self moves (Strengthen, Stance "Heroik", Stance "Kilau").
	if move.target_type == Move.Target.SELF:
		battle_log.emit("%s uses %s!" % [user.stats.character_name, move.move_name])
		return

	for target in targets:
		if not is_instance_valid(target) or not target.is_alive():
			continue

		if move.is_heal:
			# Heals: % of the TARGET's max HP (Field Heal), Capability-based flat
			# (Rejuvenate), or the old flat power + Capability. Always rounded up.
			var amount: int
			if move.heal_pct_base > 0.0 or move.heal_pct_per_cap > 0.0:
				var pct: float = move.heal_pct_base + user.get_capability() * move.heal_pct_per_cap
				amount = Move.round_up(target.stats.max_health * pct / 100.0)
			elif move.heal_flat_per_cap > 0.0:
				amount = Move.round_up(user.get_capability() * move.heal_flat_per_cap)
			else:
				amount = move.power + user.get_capability()
			target.heal(amount)
			battle_log.emit("%s uses %s, healing %s for %d HP!" % [
				user.stats.character_name, move.move_name, target.stats.character_name, amount
			])
			continue

		if move.grants_energy_allies > 0:
			target.gain_energy(move.grants_energy_allies)
			battle_log.emit("%s uses %s: %s gains %d Energy!" % [
				user.stats.character_name, move.move_name, target.stats.character_name, move.grants_energy_allies
			])
			continue

		# Multi-hit moves (Heroic = 2): each hit rolls dodge/crit separately,
		# and stops early if the target is already down.
		var landed := false
		for i in range(move.hits):
			if not target.is_alive():
				break
			var connected := _resolve_hit(user, move, target, move.inflicts_per_hit or not landed)
			landed = landed or connected

	# Once-per-use heal for the user (Encompass).
	if move.self_heal_flat > 0:
		user.heal(move.self_heal_flat)
		battle_log.emit("%s recovers %d HP!" % [user.stats.character_name, move.self_heal_flat])

## One damaging hit: dodge -> damage (+crit) -> lifesteal -> execute -> stun.
## Returns true if the hit connected (was not dodged).
func _resolve_hit(user: BattleUnit, move: Move, target: BattleUnit, apply_inflicts: bool = true) -> bool:
	if target.roll_dodge():
		battle_log.emit("%s dodges %s's %s!" % [
			target.stats.character_name, user.stats.character_name, move.move_name
		])
		attack_dodged.emit(target, user)
		if move.effects_ignore_dodge:
			_apply_hit_statuses(move, target, apply_inflicts)
		return false

	# Javelin: the "below 50% HP" check uses the HP the target had BEFORE this hit.
	var stun_by_low_hp := move.stun_if_target_below_hp_pct > 0.0 \
		and float(target.current_health) / float(target.stats.max_health) < move.stun_if_target_below_hp_pct

	var dealt: int = 0
	if move.deals_damage:
		var raw: int = move.damage_per_hit(user.get_attack(), user.get_capability(), user.get_speed())

		var is_crit := randf() < crit_chance # fixed 1-in-14 for allies AND enemies
		if is_crit:
			raw = Move.round_up(raw * CRIT_MULTIPLIER)

		dealt = target.take_damage(raw)
		battle_log.emit("%s uses %s on %s for %d damage!%s" % [
			user.stats.character_name, move.move_name, target.stats.character_name, dealt,
			" (CRITICAL!)" if is_crit else ""
		])
	else:
		# No-damage move (Secure, Encompass): it connected, only side effects follow.
		battle_log.emit("%s uses %s on %s!" % [
			user.stats.character_name, move.move_name, target.stats.character_name
		])

	# Lifesteal (Absorption): heals a share of the damage actually dealt.
	if move.lifesteal > 0.0 and dealt > 0:
		var healed := Move.round_up(dealt * move.lifesteal)
		user.heal(healed)
		battle_log.emit("%s recovers %d HP!" % [user.stats.character_name, healed])

	# Execute (old Condemn): checked AFTER the damage lands, ignores Guard.
	if move.execute_base > 0 and target.is_alive():
		var threshold: float = move.execute_base + user.get_capability() * move.execute_per_cap
		if target.current_health < threshold:
			target.kill()
			battle_log.emit("%s is condemned!" % target.stats.character_name)

	# Kill rewards: Condemn heals the user, Berandalan refunds energy.
	if dealt > 0 and not target.is_alive():
		if move.heal_self_on_kill_pct > 0.0:
			var kill_heal := Move.round_up(user.stats.max_health * move.heal_self_on_kill_pct / 100.0)
			user.heal(kill_heal)
			battle_log.emit("%s recovers %d HP!" % [user.stats.character_name, kill_heal])
		if move.energy_on_kill > 0:
			user.gain_energy(move.energy_on_kill)
			battle_log.emit("%s regains %d Energy!" % [user.stats.character_name, move.energy_on_kill])

	# Stun (Backhand, Enchain, Overcome) and `inflicts` statuses (Gloop, Fire...):
	# only land if the hit connected and the target lived.
	_apply_hit_statuses(move, target, apply_inflicts)
	if stun_by_low_hp and target.is_alive():
		target.add_status(StatusDefs.Kind.STUN, 1, 1)

	# On-hit self-heal (Secure): Capability/125 of the user's max HP.
	if move.self_heal_max_hp_per_cap > 0.0:
		var self_healed := Move.round_up(user.stats.max_health * user.get_capability() * move.self_heal_max_hp_per_cap)
		user.heal(self_healed)
		battle_log.emit("%s recovers %d HP!" % [user.stats.character_name, self_healed])

	# Flame Wings: whoever connects with the holder catches a stack of Fire.
	if target.has_status(StatusDefs.Kind.FLAME_WINGS):
		user.add_status(StatusDefs.Kind.FIRE)
	return true

## Stun + the move's `inflicts` list, applied to one target.
func _apply_hit_statuses(move: Move, target: BattleUnit, with_inflicts: bool = true) -> void:
	if not target.is_alive():
		return
	if move.stun_turns > 0:
		target.add_status(StatusDefs.Kind.STUN, 1, move.stun_turns)
	if with_inflicts:
		_apply_statuses(target, move.inflicts, null)

## `source` is the unit using the move; it supplies the Capability for magnitude_per_cap.
func _apply_statuses(unit: BattleUnit, applications: Array, source: BattleUnit = null) -> void:
	for a in applications:
		if a:
			var magnitude: int = a.magnitude
			if source != null and a.magnitude_per_cap > 0.0:
				magnitude += Move.round_up(source.get_capability() * a.magnitude_per_cap)
			unit.add_status(a.kind, a.stacks, a.duration, magnitude)

func _resolve_item(user: BattleUnit, item: Item, targets: Array) -> void:
	if party_inventory.get(item, 0) <= 0:
		battle_log.emit("No %s left!" % item.item_name)
		return
	party_inventory[item] -= 1
	for target in targets:
		if not is_instance_valid(target):
			continue
		# Percent items heal a share of the TARGET's max HP; old flat items use heal_amount.
		var amount: int = item.heal_amount
		if item.heal_pct > 0.0:
			amount = Move.round_up(target.stats.max_health * item.heal_pct / 100.0)
		if item.revive and not target.is_alive():
			target.current_health = clampi(amount, 1, target.stats.max_health)
			target.hp_changed.emit(target, target.current_health)
			battle_log.emit("%s uses %s to revive %s!" % [
				user.stats.character_name, item.item_name, target.stats.character_name
			])
		elif target.is_alive():
			if amount > 0:
				target.heal(amount)
			if item.energy_gain > 0:
				target.gain_energy(item.energy_gain)
			for b in item.buffs:
				target.add_status(b.kind, b.stacks, b.duration, b.magnitude)
			battle_log.emit("%s uses %s on %s!" % [
				user.stats.character_name, item.item_name, target.stats.character_name
			])

## Returns true when the whole battle is over. Clearing a wave that is not the
## last one spawns the next wave and returns false.
func _check_battle_over() -> bool:
	var players_alive: bool = not player_team.filter(func(u): return u.is_alive()).is_empty()
	var enemies_alive: bool = not enemy_team.filter(func(u): return u.is_alive()).is_empty()
	if not players_alive:
		battle_log.emit("The party has been defeated...")
		battle_ended.emit(false)
		return true
	if not enemies_alive:
		if current_wave < wave_count and wave_factory.is_valid():
			await _spawn_next_wave()
			return false
		battle_log.emit("Victory!")
		battle_ended.emit(true)
		return true
	return false

func _spawn_next_wave() -> void:
	battle_log.emit("Wave cleared!")
	await get_tree().create_timer(1.0).timeout
	var units: Array = wave_factory.call(current_wave)
	current_wave += 1
	var typed: Array[BattleUnit] = []
	typed.assign(units)
	enemy_team = typed
	for u in typed:
		_hook_unit(u)
		get_parent().add_child(u) # so _ready sets its HP
	battle_log.emit("=== Wave %d of %d ===" % [current_wave, wave_count])
	wave_started.emit(typed)

## Test hook: resolves one hit and returns the HP the target lost.
func _resolve_hit_for_test(user: BattleUnit, move: Move, target: BattleUnit) -> int:
	var before := target.current_health
	_resolve_hit(user, move, target)
	return before - target.current_health
