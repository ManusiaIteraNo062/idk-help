extends Node2D
class_name BattleStage
## Placeholder battlefield visuals: one stick figure per unit, in a 2x2 grid
## per side (party left, enemies right), placed from the actual viewport size
## so it follows window resizes and wider screens. Purely visual;
## BattleManager/BattleUnit logic doesn't know this exists. Swap
## CharacterPlaceholder's drawing for real art later without touching this.
##
## Also draws: a white marker over the unit whose turn it is, gold markers over
## whatever the Target menu is hovering, and floating damage / heal numbers.

@export var battle_manager: BattleManager

const PLAYER_COLOR := Color.WHITE
const ENEMY_COLOR := Color(0.85, 0.2, 0.2) # red, matches the reference art
const DEFEATED_TINT := Color(0.3, 0.3, 0.3, 0.5)

## Must match the space BattleUI uses at the bottom/top (see BattleUI).
const TOP_RESERVED := 150.0     # TURN/WAVE panels + enemy list live above this
const BOTTOM_RESERVED := 258.0  # party bar + action panel + margins

var _figures: Dictionary = {}   # BattleUnit -> CharacterPlaceholder
var _slots: Dictionary = {}     # BattleUnit -> { "party": bool, "index": int, "count": int }
var _enemy_units: Array = []    # enemies currently on stage (replaced each wave)
var _last_hp: Dictionary = {}   # BattleUnit -> HP last time we looked (for floating numbers)
var _markers: Dictionary = {}   # BattleUnit -> FieldMarker
var _active_unit: BattleUnit

func _ready() -> void:
	position = Vector2.ZERO # layout is in screen space now; ignore any old offset
	z_index = -1            # UI panels draw on top of the field
	if not battle_manager:
		push_warning("BattleStage: battle_manager not set, no figures spawned.")
		return
	_spawn_team(battle_manager.player_team, true)
	_spawn_team(battle_manager.enemy_team, false)
	_enemy_units = battle_manager.enemy_team.duplicate()
	_apply_layout()
	get_viewport().size_changed.connect(_apply_layout)
	battle_manager.wave_started.connect(_on_wave_started)
	battle_manager.attack_dodged.connect(_on_dodged)
	battle_manager.player_turn_started.connect(func(u, _a): _set_active(u))
	battle_manager.enemy_turn_started.connect(func(_u): _set_active(null))
	battle_manager.battle_ended.connect(func(_w): _set_active(null))
	# Hook up to the BattleUI next to us (if any) so the Target menu shows markers.
	for sibling in get_parent().get_children():
		if sibling is BattleUI:
			sibling.target_focused.connect(show_target_markers)

func _spawn_team(team: Array, party: bool) -> void:
	for i in range(team.size()):
		var unit: BattleUnit = team[i]
		var figure := CharacterPlaceholder.new()
		figure.color = PLAYER_COLOR if party else ENEMY_COLOR
		add_child(figure)

		var label := Label.new()
		label.name = "NameLabel"
		label.text = unit.stats.character_name
		label.custom_minimum_size = Vector2(130, 0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 14)
		figure.add_child(label)

		_figures[unit] = figure
		_slots[unit] = {"party": party, "index": i, "count": team.size()}
		_last_hp[unit] = unit.current_health
		unit.defeated.connect(_on_unit_defeated)
		unit.hp_changed.connect(_on_hp_changed)

# ---- layout -------------------------------------------------------------

func _apply_layout() -> void:
	var size := get_viewport_rect().size
	var fs := 0.65 * clampf(size.y / 648.0, 1.0, 1.6)
	var field_top := TOP_RESERVED
	var field_bottom := size.y - BOTTOM_RESERVED
	var row1 := field_top + 52.0 * fs / 0.65
	var row2 := field_bottom - 58.0 * fs / 0.65
	var mid := (row1 + row2) * 0.5
	var party_x := [size.x * 0.20, size.x * 0.35]
	var enemy_x := [size.x * 0.62, size.x * 0.77]

	for unit in _figures:
		var fig: CharacterPlaceholder = _figures[unit]
		if not is_instance_valid(fig):
			continue
		var slot: Dictionary = _slots[unit]
		var i: int = slot["index"]
		var n: int = slot["count"]
		var xs: Array = party_x if slot["party"] else enemy_x
		var pos: Vector2
		var scale_mult := 1.0
		if slot["party"] and n <= 2:
			pos = Vector2(xs[i], mid) # a small party (e.g. mission 1) stands in the middle row
		elif slot["party"]:
			# Helder, Radik on top; Dean, WYG-01 below (slightly staggered like the sketch).
			var col := i % 2
			var row := i / 2
			pos = Vector2(xs[col] + (size.x * 0.02 if row == 1 else 0.0), row1 if row == 0 else row2)
		elif n == 1:
			pos = Vector2((xs[0] + xs[1]) * 0.5, mid)
			scale_mult = 1.45 if unit.is_boss else 1.0
		elif n == 2:
			pos = Vector2(xs[i], mid)
		else:
			# A B / C D, the same order as the 2x2 target buttons.
			var col2 := i % 2
			var row2i := i / 2
			pos = Vector2(xs[col2] + (size.x * 0.02 if row2i == 1 else 0.0), row1 if row2i == 0 else row2)
		fig.figure_scale = fs * scale_mult
		fig.position = pos
		fig.queue_redraw()
		var feet := 50.0 * fig.figure_scale
		fig.get_node("NameLabel").position = Vector2(-65, feet + 8)
	for unit in _markers:
		_place_marker(unit)

# ---- waves / defeat -------------------------------------------------------

## A new wave arrived: remove the old enemy figures and place the new ones.
func _on_wave_started(units: Array) -> void:
	for u in _enemy_units:
		if _figures.has(u):
			_figures[u].queue_free()
			_figures.erase(u)
		_slots.erase(u)
		_last_hp.erase(u)
		if _markers.has(u):
			_markers[u].queue_free()
			_markers.erase(u)
	_enemy_units = units.duplicate()
	_spawn_team(units, false)
	_apply_layout()

func _on_unit_defeated(unit: BattleUnit) -> void:
	if _figures.has(unit):
		_figures[unit].modulate = DEFEATED_TINT
	_clear_marker(unit)

# ---- floating numbers -----------------------------------------------------

func _on_hp_changed(unit: BattleUnit, new_hp: int) -> void:
	var old: int = _last_hp.get(unit, new_hp)
	_last_hp[unit] = new_hp
	var delta := new_hp - old
	if delta == 0 or not _figures.has(unit) or not is_instance_valid(_figures[unit]):
		return
	var fig: CharacterPlaceholder = _figures[unit]
	var lbl := Label.new()
	lbl.text = ("+%d" % delta) if delta > 0 else str(delta)
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5) if delta > 0 else Color(1.0, 0.45, 0.4))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.position = fig.position + Vector2(randf_range(-26.0, 6.0), -72.0 * fig.figure_scale / 0.65 - 10.0)
	lbl.z_index = 5
	add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 44.0, 0.9)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.9).set_delay(0.4)
	tw.chain().tween_callback(lbl.queue_free)

## "Dodge!" over the target (any attack, even one that deals no damage) plus a
## quick side-step away from the attacker's side.
func _on_dodged(target: BattleUnit, _attacker: BattleUnit) -> void:
	if not _figures.has(target) or not is_instance_valid(_figures[target]):
		return
	var fig: CharacterPlaceholder = _figures[target]
	var lbl := Label.new()
	lbl.text = "Dodge!"
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.position = fig.position + Vector2(-30.0, -72.0 * fig.figure_scale / 0.65 - 10.0)
	lbl.z_index = 5
	add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 36.0, 0.9)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.9).set_delay(0.4)
	tw.chain().tween_callback(lbl.queue_free)
	# side-step: party steps left, enemies step right (away from the other side)
	var dir := -1.0 if _slots.get(target, {}).get("party", true) else 1.0
	var home := fig.position
	var step := create_tween()
	step.tween_property(fig, "position:x", home.x + dir * 18.0, 0.1)
	step.tween_property(fig, "position:x", home.x, 0.16)

# ---- markers ----------------------------------------------------------------

func _set_active(unit: BattleUnit) -> void:
	if _active_unit != null:
		_clear_marker(_active_unit)
	_active_unit = unit
	if unit != null:
		_show_marker(unit, Color.WHITE)

## Gold markers over the units the Target menu is hovering (empty = none).
func show_target_markers(units: Array) -> void:
	for u in _markers.keys():
		if u != _active_unit:
			_clear_marker(u)
	for u in units:
		_show_marker(u, Color(1.0, 0.82, 0.2))

func _show_marker(unit: BattleUnit, color: Color) -> void:
	if not _figures.has(unit):
		return
	var m: FieldMarker = _markers.get(unit)
	if m == null:
		m = FieldMarker.new()
		add_child(m)
		_markers[unit] = m
	m.color = color
	m.queue_redraw()
	_place_marker(unit)

func _place_marker(unit: BattleUnit) -> void:
	var m: FieldMarker = _markers.get(unit)
	var fig: CharacterPlaceholder = _figures.get(unit)
	if m == null or fig == null:
		return
	m.position = fig.position + Vector2(0, -78.0 * fig.figure_scale / 0.65 * 0.65 - 16.0)

func _clear_marker(unit: BattleUnit) -> void:
	if _markers.has(unit):
		_markers[unit].queue_free()
		_markers.erase(unit)

## A small downward-pointing arrow drawn above a unit's head.
class FieldMarker extends Node2D:
	var color: Color = Color.WHITE
	func _draw() -> void:
		draw_colored_polygon(PackedVector2Array([Vector2(-9, -10), Vector2(9, -10), Vector2(0, 4)]), color)
		draw_polyline(PackedVector2Array([Vector2(-9, -10), Vector2(9, -10), Vector2(0, 4), Vector2(-9, -10)]), Color.BLACK, 1.5)
