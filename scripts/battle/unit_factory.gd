extends RefCounted
class_name UnitFactory
## Code-built units and moves, moved out of battle_demo.gd so every mission
## (and later, real .tres data) can share them.

static func make_unit(unit_name: String, health: int, attack: int, capability: int, speed: int) -> BattleUnit:
	var stats := CharacterStats.new()
	stats.character_name = unit_name
	stats.max_health = health
	stats.attack = attack
	stats.capability = capability
	stats.speed = speed

	var unit := BattleUnit.new()
	unit.name = unit_name
	unit.stats = stats

	var strike := Move.new()
	strike.move_name = "Strike"
	strike.type = Move.Type.BASIC
	strike.power = 6
	strike.target_type = Move.Target.SINGLE_ENEMY
	unit.basic_moves.append(strike)

	return unit

static func add_alteration(unit: BattleUnit, move_name: String, cost: int, power: int, target: Move.Target) -> void:
	var move := Move.new()
	move.move_name = move_name
	move.type = Move.Type.ALTERATION
	move.energy_cost = cost
	move.power = power
	move.target_type = target
	unit.alteration_moves.append(move)

## type = physical (BASIC, scales off Attack) or magical (ALTERATION, scales
## off Capability). For enemies it has nothing to do with energy.
static func make_enemy_move(move_name: String, power: int, target: Move.Target, type: Move.Type = Move.Type.BASIC) -> Move:
	var move := Move.new()
	move.move_name = move_name
	move.power = power
	move.target_type = target
	move.type = type
	return move

static func make_moveset(moves: Array[Move]) -> EnemyMoveset:
	var ms := EnemyMoveset.new()
	ms.moves = moves
	return ms

## A pattern-based enemy: no basic moves, just a repeating moveset.
static func make_enemy(unit_name: String, health: int, attack: int, capability: int, speed: int, moves: Array[Move]) -> BattleUnit:
	var unit := make_unit(unit_name, health, attack, capability, speed)
	unit.basic_moves.clear()
	unit.moveset = make_moveset(moves)
	return unit

## Builds the party from the Roster: stats include the active upgrade and the
## worn equipment (GameState.stats_for), and the Alteration list is the
## character's known skills (base skills + any learned in the workshop).
## (GameState.load_or_new() guarantees valid equipment.)
## `only` = Roster ids that take part (empty = the whole party).
static func make_player_team(state: GameState, only: PackedStringArray = PackedStringArray()) -> Array[BattleUnit]:
	var team: Array[BattleUnit] = []
	for d in Roster.all():
		if not only.is_empty() and not d.id in only:
			continue
		var st := state.stats_for(d.id)
		var unit := make_unit(d.display_name, st["health"], st["attack"], st["capability"], st["speed"])
		unit.basic_moves[0].move_name = d.basic_name

		for skill in SkillLibrary.for_character(d.id):
			if state.knows_skill(skill):
				for move in skill.build_moves():
					unit.alteration_moves.append(move)

		team.append(unit)
	return team
