extends Resource
class_name EnemyType
## A reusable enemy template: stats + moves + behavior.
## Lives in data/enemies/<id>.tres and can be dropped into any mission's waves.
## build_unit() creates a FRESH BattleUnit every call (own cooldowns, own HP).
##
## Enemy damage is FIXED: a move's `power` is the damage dealt (scaling_mult 0),
## so attack/capability are unused for these enemies. `speed` is still the
## dodge chance in %, and is 0 for everything for now.

@export var display_name: String = "Altered"
@export var health: int = 50
@export var speed: int = 0
@export var moves: Array[Move] = []
@export var ai: EnemyMoveset.Mode = EnemyMoveset.Mode.PRIORITIZE_BIG
## Bosses act more than once per turn.
@export var actions_per_turn: int = 1

func build_unit() -> BattleUnit:
	var move_list: Array[Move] = []
	move_list.assign(moves)
	var unit := UnitFactory.make_enemy(display_name, health, 0, 0, speed, move_list)
	unit.moveset.mode = ai
	unit.actions_per_turn = actions_per_turn
	return unit
