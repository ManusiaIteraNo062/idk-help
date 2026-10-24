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

@export var moves: Array[Move] = []

var _index: int = 0

## Returns the next move in the pattern and advances the cycle.
func next_move() -> Move:
	if moves.is_empty():
		return null
	var move := moves[_index % moves.size()]
	_index += 1
	return move

func reset() -> void:
	_index = 0
