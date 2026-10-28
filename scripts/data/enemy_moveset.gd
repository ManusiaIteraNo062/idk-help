extends Resource
class_name EnemyMoveset
## The enemy-side equivalent of "Basic + Alteration" - except it isn't
## split into two types and isn't gated by energy at all. An enemy with a
## moveset just cycles through `moves` in a fixed, repeating order every
## time it acts. A single-entry moveset means "always does this one move."
## A multi-entry moveset gives you Darkest-Dungeon-style telegraphed
## patterns (e.g. two attacks then a heal, forever).
##
## Moves used here can reuse the same Move resource class as the player
## side (power, target_type, is_heal all still apply) - `type` and
## `energy_cost` are simply ignored for enemies.

## CYCLE = the original fixed repeating pattern (still used by battle_demo).
## PRIORITIZE_BIG = mobs: random ready "big" move (one with a cooldown), else a random
##   ready basic move.
## RANDOM = bosses: random move among those that are off cooldown.
enum Mode { CYCLE, PRIORITIZE_BIG, RANDOM }

@export var moves: Array[Move] = []
@export var mode: Mode = Mode.CYCLE

var _index: int = 0

## Picks this turn's move for `unit`, respecting its cooldowns. Returns null
## only if the moveset is empty.
func choose(unit: BattleUnit) -> Move:
	if mode == Mode.CYCLE:
		return next_move()
	if moves.is_empty():
		return null
	var ready: Array = moves.filter(func(m: Move): return unit.is_ready(m))
	if ready.is_empty():
		return moves.pick_random() # every move cooling down: shouldn't happen, but never stall
	if mode == Mode.PRIORITIZE_BIG:
		var big: Array = ready.filter(func(m: Move): return m.cooldown > 0)
		if not big.is_empty():
			return big.pick_random()
	return ready.pick_random()

## Returns the next move in the pattern and advances the cycle.
func next_move() -> Move:
	if moves.is_empty():
		return null
	var move := moves[_index % moves.size()]
	_index += 1
	return move

func reset() -> void:
	_index = 0
