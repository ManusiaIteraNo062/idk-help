extends Resource
class_name Mission
## One entry on the mission board: its blurb, its story beats, and a
## function that builds a fresh enemy team each time the mission starts.

@export var id: StringName = &""
@export var title: String = "Mission"
@export var difficulty: String = "Standard" # shown on the board, e.g. "Tutorial"
@export_multiline var summary: String = ""
@export var chapter_label: String = ""  # e.g. "Level 1 - Prologue" (title card)
@export var location: String = ""       # e.g. "TARAKAN, LAMPUNG" (title card + board)

## Shangri-La Fragments for the FIRST clear. Replays pay a reduced share
## (REPLAY_REWARD_RATIO in game_flow.gd).
@export var fragment_reward: int = 20

@export var intro_lines: Array[DialogueLine] = []   # before the battle
@export var victory_lines: Array[DialogueLine] = [] # after a win
@export var defeat_lines: Array[DialogueLine] = []  # after a loss

## Returns Array[BattleUnit]. A Callable (not an exported array) so every
## attempt gets fresh enemies with full HP and a reset attack pattern.
var build_enemies: Callable
