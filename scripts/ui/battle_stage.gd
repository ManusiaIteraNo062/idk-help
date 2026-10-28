extends Node2D
class_name BattleStage
## Placeholder battlefield visuals: one stick figure per unit, positioned
## in a 2x2 grid - player team on the left, enemy team on the right.
## Purely visual; BattleManager/BattleUnit logic doesn't know this exists.
## Swap CharacterPlaceholder's drawing for real art later without
## touching this positioning code.

@export var battle_manager: BattleManager

const PLAYER_POSITIONS: Array[Vector2] = [
	Vector2(-380, -120), Vector2(-230, -120),
	Vector2(-380, 100), Vector2(-230, 100),
]
# Enemy slots fill the BOTTOM row first (same line as Dean and Admin),
# nudged toward the middle so they stay clear of the enemy HP panel in the
# top-right corner. Slots 3-4 (the top row) are only used by bigger encounters.
const ENEMY_POSITIONS: Array[Vector2] = [
	Vector2(180, 100), Vector2(330, 100),
	Vector2(180, -120), Vector2(330, -120),
]

const PLAYER_COLOR := Color.WHITE
const ENEMY_COLOR := Color(0.85, 0.2, 0.2) # red, matches the reference art
const DEFEATED_TINT := Color(0.3, 0.3, 0.3, 0.5)

var _figures: Dictionary = {} # BattleUnit -> CharacterPlaceholder
var _enemy_units: Array = []   # enemies currently on stage (replaced each wave)

func _ready() -> void:
	if not battle_manager:
		push_warning("BattleStage: battle_manager not set, no figures spawned.")
		return
	_spawn_team(battle_manager.player_team, PLAYER_POSITIONS, PLAYER_COLOR)
	_spawn_team(battle_manager.enemy_team, ENEMY_POSITIONS, ENEMY_COLOR)
	_enemy_units = battle_manager.enemy_team.duplicate()
	battle_manager.wave_started.connect(_on_wave_started)

func _spawn_team(team: Array, positions: Array[Vector2], color: Color) -> void:
	for i in range(team.size()):
		var unit: BattleUnit = team[i]
		var figure := CharacterPlaceholder.new()
		figure.color = color
		figure.figure_scale = 0.8
		figure.position = positions[i % positions.size()]
		add_child(figure)

		var label := Label.new()
		label.text = unit.stats.character_name
		label.position = Vector2(-40, 60)
		label.custom_minimum_size = Vector2(80, 0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		figure.add_child(label)

		_figures[unit] = figure
		unit.defeated.connect(_on_unit_defeated)

## A new wave arrived: remove the old enemy figures and place the new ones.
func _on_wave_started(units: Array) -> void:
	for u in _enemy_units:
		if _figures.has(u):
			_figures[u].queue_free()
			_figures.erase(u)
	_enemy_units = units.duplicate()
	_spawn_team(units, ENEMY_POSITIONS, ENEMY_COLOR)

func _on_unit_defeated(unit: BattleUnit) -> void:
	if _figures.has(unit):
		_figures[unit].modulate = DEFEATED_TINT
