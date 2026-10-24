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

@export var player_team: Array[BattleUnit] = [] # up to 4 (rule 3)
@export var enemy_team: Array[BattleUnit] = []

var party_inventory: Dictionary = {} # Item -> int quantity

const CRIT_CHANCE := 1.0 / 14.0 # fixed for BOTH allies and enemies
const CRIT_MULTIPLIER := 1.5

var _round_number: int = 0
var _pending_action: Dictionary = {}
var _waiting_for_player: bool = false

signal _player_action_submitted

func add_item(item: Item, quantity: int = 1) -> void:
	party_inventory[item] = party_inventory.get(item, 0) + quantity

func start_battle() -> void:
	_round_number = 0
	_run_battle_loop()

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
			if _check_battle_over():
				return

		# Enemy team moves second.
		for unit in enemy_team:
			if not unit.is_alive():
				continue
			_process_enemy_turn(unit)
			if _check_battle_over():
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

## Returns true if the unit loses its turn to a stun (and ticks the stun
## down by one). Called BEFORE anything else in a turn, so a stunned enemy's
## fixed pattern does not advance on the lost turn.
func _consume_stun(unit: BattleUnit) -> bool:
	if unit.stun_turns <= 0:
		return false
	unit.stun_turns -= 1
	battle_log.emit("%s is stunned and loses the turn!" % unit.stats.character_name)
	return true

func _process_player_turn(unit: BattleUnit) -> void:
	if _consume_stun(unit):
		return
	player_turn_started.emit(unit, get_available_actions(unit))
	_waiting_for_player = true
	await _player_action_submitted
	_waiting_for_player = false
	_execute_action(unit, _pending_action)

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

func _process_enemy_turn(unit: BattleUnit) -> void:
	if _consume_stun(unit):
		return
	enemy_turn_started.emit(unit)
	var action_data := _choose_enemy_action(unit)
	_execute_action(unit, action_data)

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
		var move: Move = unit.moveset.next_move()
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

	match type:
		"enemy_move":
			# Fixed-pattern enemy move: no Basic/Alteration split, no energy
			# cost, no energy gain. The pattern itself is the only limiter.
			_resolve_move(unit, action_data["move"], targets)
		"basic":
			# Basic moves are free, and using one still fills the bar (rule 6).
			_resolve_move(unit, action_data["move"], targets)
			unit.gain_energy(1)
		"alteration":
			var move: Move = action_data["move"]
			if unit.can_use_move(move) and unit.spend_energy(move.energy_cost):
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
			unit.is_guarding = true
			battle_log.emit("%s guards." % unit.stats.character_name)
			unit.gain_energy(1)

	action_resolved.emit(unit, "%s's turn resolved." % unit.stats.character_name)

func _resolve_move(user: BattleUnit, move: Move, targets: Array) -> void:
	# Self-buff (Oxypetalum - Strengthen): no dodge, no damage.
	if move.buff_attack_flat != 0 or move.buff_attack_cap_mult != 0.0:
		var gain: int = move.buff_attack_flat + int(user.stats.capability * move.buff_attack_cap_mult)
		user.bonus_attack += gain
		battle_log.emit("%s uses %s, gaining %d Attack!" % [
			user.stats.character_name, move.move_name, gain
		])
		return

	for target in targets:
		if not is_instance_valid(target) or not target.is_alive():
			continue

		if move.is_heal:
			# Heals scale off Capability too - it's the "magic power" stat,
			# and healing is a support Alteration.
			var amount: int
			if move.heal_pct_base > 0.0 or move.heal_pct_per_cap > 0.0:
				# Percent of the TARGET's max HP (Supplication).
				var pct: float = move.heal_pct_base + user.stats.capability * move.heal_pct_per_cap
				amount = int(target.stats.max_health * pct / 100.0)
			else:
				amount = move.power + user.stats.capability
			target.heal(amount)
			battle_log.emit("%s uses %s, healing %s for %d HP!" % [
				user.stats.character_name, move.move_name, target.stats.character_name, amount
			])
			continue

		# Multi-hit moves (Heroic = 2): each hit rolls dodge/crit separately,
		# and stops early if the target is already down.
		for i in range(move.hits):
			if not target.is_alive():
				break
			_resolve_hit(user, move, target)

## One damaging hit: dodge -> damage (+crit) -> lifesteal -> execute -> stun.
func _resolve_hit(user: BattleUnit, move: Move, target: BattleUnit) -> void:
	if target.roll_dodge():
		battle_log.emit("%s dodges %s's %s!" % [
			target.stats.character_name, user.stats.character_name, move.move_name
		])
		return

	# BASIC = physical, scales off Attack (including buffs). ALTERATION =
	# magic/special, scales off Capability. This applies to enemy
	# fixed-pattern moves too - Move.type just means "physical or magical".
	var dealt: int = 0
	if move.deals_damage:
		var scaling_stat: int = user.stats.capability if move.type == Move.Type.ALTERATION else user.get_attack()
		var raw: int = max(1, int(move.power + scaling_stat * move.scaling_mult + user.stats.speed * move.speed_mult))

		var is_crit := randf() < CRIT_CHANCE # fixed 1-in-14 for allies AND enemies
		if is_crit:
			raw = int(raw * CRIT_MULTIPLIER)

		dealt = target.take_damage(raw)
		battle_log.emit("%s uses %s on %s for %d damage!%s" % [
			user.stats.character_name, move.move_name, target.stats.character_name, dealt,
			" (CRITICAL!)" if is_crit else ""
		])
	else:
		# No-damage move (Secure): it connected, but only side effects follow.
		battle_log.emit("%s uses %s on %s!" % [
			user.stats.character_name, move.move_name, target.stats.character_name
		])

	# Lifesteal (Absorption): heals the damage actually dealt.
	if move.lifesteal > 0.0 and dealt > 0:
		var healed := int(dealt * move.lifesteal)
		user.heal(healed)
		battle_log.emit("%s recovers %d HP!" % [user.stats.character_name, healed])

	# Execute (Condemn): checked AFTER the damage lands, ignores Guard.
	if move.execute_base > 0 and target.is_alive():
		var threshold: float = move.execute_base + user.stats.capability * move.execute_per_cap
		if target.current_health < threshold:
			target.kill()
			battle_log.emit("%s is condemned!" % target.stats.character_name)

	# Stun (Backhand): only lands if the hit connected and the target lived.
	if move.stun_turns > 0 and target.is_alive():
		target.stun_turns = max(target.stun_turns, move.stun_turns)
		battle_log.emit("%s is stunned!" % target.stats.character_name)

	# On-hit self-heal (Secure): Capability/125 of the user's max HP.
	if move.self_heal_max_hp_per_cap > 0.0:
		var self_healed := int(user.stats.max_health * user.stats.capability * move.self_heal_max_hp_per_cap)
		user.heal(self_healed)
		battle_log.emit("%s recovers %d HP!" % [user.stats.character_name, self_healed])

func _resolve_item(user: BattleUnit, item: Item, targets: Array) -> void:
	if party_inventory.get(item, 0) <= 0:
		battle_log.emit("No %s left!" % item.item_name)
		return
	party_inventory[item] -= 1
	for target in targets:
		if not is_instance_valid(target):
			continue
		if item.revive and not target.is_alive():
			target.current_health = int(target.stats.max_health * 0.5)
			target.hp_changed.emit(target, target.current_health)
			battle_log.emit("%s uses %s to revive %s!" % [
				user.stats.character_name, item.item_name, target.stats.character_name
			])
		elif target.is_alive():
			target.heal(item.heal_amount)
			battle_log.emit("%s uses %s on %s, healing %d HP!" % [
				user.stats.character_name, item.item_name, target.stats.character_name, item.heal_amount
			])

func _check_battle_over() -> bool:
	var players_alive: bool = not player_team.filter(func(u): return u.is_alive()).is_empty()
	var enemies_alive: bool = not enemy_team.filter(func(u): return u.is_alive()).is_empty()
	if not players_alive:
		battle_log.emit("The party has been defeated...")
		battle_ended.emit(false)
		return true
	if not enemies_alive:
		battle_log.emit("Victory!")
		battle_ended.emit(true)
		return true
	return false
