extends Resource
class_name Mission
## One entry on the mission board. Lives in data/missions/<NN_name>/mission.tres;
## the dialogue lines come from intro.txt / victory.txt / defeat.txt in the same
## folder and are filled in by MissionLibrary when the game loads.

@export var id: StringName = &""
@export var title: String = "Mission"
@export var difficulty: String = "Standard" # shown on the board, e.g. "Tutorial"
@export_multiline var summary: String = ""
@export var chapter_label: String = ""  # e.g. "Level 1 - Prologue" (title card)
@export var location: String = ""       # e.g. "TARAHAN, LAMPUNG" (title card + board)

## Shangri-La Fragments for the FIRST clear. Replays pay a reduced share
## (REPLAY_REWARD_RATIO in game_flow.gd).
@export var fragment_reward: int = 20

## Enemy groups, in order. The GDD wants 2 / 3 / 1 waves for the three levels;
## game_flow currently plays wave 0 only until multi-wave combat exists.
@export var waves: Array[EnemyWave] = []

# Filled by MissionLibrary from the .txt files (not edited in the inspector).
var intro_lines: Array[DialogueLine] = []   # before the battle
var victory_lines: Array[DialogueLine] = [] # after a win
var defeat_lines: Array[DialogueLine] = []  # after a loss

func wave_count() -> int:
	return waves.size()

## Fresh enemies (full HP, pattern reset) for one wave.
func build_wave(index: int = 0) -> Array[BattleUnit]:
	var team: Array[BattleUnit] = []
	if index < 0 or index >= waves.size() or waves[index] == null:
		push_error("Mission '%s' has no wave %d" % [id, index])
		return team
	for e in waves[index].enemies:
		if e:
			team.append(e.build_unit())
	# "Sloppy Altered" x4 -> "Sloppy Altered A..D" so target buttons are distinguishable.
	var totals := {}
	for u in team:
		totals[u.stats.character_name] = totals.get(u.stats.character_name, 0) + 1
	var seen := {}
	for u in team:
		var base: String = u.stats.character_name
		if totals[base] > 1:
			var n: int = seen.get(base, 0)
			seen[base] = n + 1
			u.stats.character_name = "%s %s" % [base, char(65 + n)]
			u.name = u.stats.character_name
	return team
