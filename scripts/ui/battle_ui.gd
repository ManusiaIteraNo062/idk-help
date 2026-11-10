extends Control
class_name BattleUI
## Battle screen UI, built in code, laid out from the user's sketches:
##
##   top-left   TURN panel, WAVE panel, "name used" strip
##   top-right  enemy list (name, HP bar, HP number; boss last)
##   bottom     "<name>'s turn"  ->  party status bar (HP + segmented EP)
##              ->  action panel: [categories] [moves/items] [Target who]
##
## Everything is anchored (top-left / top-right / bottom-center), so wider
## windows just get more empty space on the sides. The battlefield itself is
## placed by BattleStage. Keyboard: arrows move, Space/Enter accepts, Esc or
## right-click goes back one step.

signal target_focused(units: Array) # units about to be targeted (empty = none); BattleStage shows markers

@export var battle_manager: BattleManager
## false = the caller starts the battle with begin() (used to show a tutorial first).
@export var autostart: bool = true

# --- look ---
const BAR_WIDTH := 820.0        # party status bar and action panel width
const PARTY_BAR_HEIGHT := 70.0
const ACTION_HEIGHT := 126.0
const MARGIN := 16.0
const GOLD := Color(0.88, 0.7, 0.3)
const GOLD_DIM := Color(0.42, 0.34, 0.17)
const PANEL_BG := Color(0.09, 0.08, 0.07, 0.94)
const TEXT_DARK := Color(0.1, 0.08, 0.03)

const CATEGORIES := [
	{"kind": "basic", "label": "ATTACK", "color": Color(0.78, 0.2, 0.18)},
	{"kind": "alteration", "label": "ALTERATION", "color": Color(0.55, 0.3, 0.78)},
	{"kind": "item", "label": "ITEM", "color": Color(0.35, 0.7, 0.3)},
	{"kind": "guard", "label": "GUARD", "color": Color(0.2, 0.62, 0.82)},
]

# --- widgets ---
var _turn_value: Label
var _wave_value: Label
var _name_used: Label
var _name_used_panel: Control
var _enemy_panel: OrnatePanel
var _enemy_rows: VBoxContainer
var _turn_label: Label
var _party_row: HBoxContainer
var _category_box: VBoxContainer
var _move_list: VBoxContainer
var _move_scroll: ScrollContainer
var _target_title: Label
var _target_grid: GridContainer
var _info_scroll: ScrollContainer
var _info_body: Label
var _hint: Label
var _picking_target: bool = false  # true while the right box shows "Target who?"

var _slot_row: HBoxContainer
var _party_cells: Dictionary = {}  # BattleUnit -> { panel, hp, hp_text, ep, ep_text, turn_label, tab, popup, popup_lines }
var _enemy_cells: Dictionary = {}  # BattleUnit -> { name, bar, text, status }
var _category_buttons: Dictionary = {} # kind -> Button

# --- menu state ---
var _current_unit: BattleUnit
var _current_actions: Dictionary
var _kind: String = "basic"     # category currently shown in the middle panel
var _on_cancel: Callable        # what Esc does right now (empty = nothing)
var _name_tween: Tween

func _ready() -> void:
	# Fill the whole screen (offsets too, or the anchored children below end up
	# inside a zero-size parent and vanish).
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top_left()
	_build_enemy_panel()
	_build_bottom()

	battle_manager.player_turn_started.connect(_on_player_turn)
	battle_manager.enemy_turn_started.connect(_on_enemy_turn)
	battle_manager.round_started.connect(func(n: int): _turn_value.text = str(n))
	battle_manager.battle_ended.connect(_on_battle_ended)
	battle_manager.wave_started.connect(_on_wave_started)
	battle_manager.action_announced.connect(_on_action_announced)

	for u in battle_manager.player_team:
		_add_party_cell(u)
		_hook_unit(u)
	for u in battle_manager.enemy_team:
		_hook_unit(u)
	_rebuild_enemy_list()
	_update_wave()
	_clear_actions()
	if autostart:
		battle_manager.start_battle()

## Starts the battle (only needed when autostart is off).
func begin() -> void:
	battle_manager.start_battle()

# ===========================================================================
# Building the static layout
# ===========================================================================

## A "LABEL | value" row like the reference game's TURN / WAVE panels.
func _info_panel(title: String) -> Array:
	var panel := OrnatePanel.new()
	panel.custom_minimum_size = Vector2(190, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 15)
	t.add_theme_color_override("font_color", GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	var box := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.03, 0.03, 0.03, 0.95)
	st.set_border_width_all(1)
	st.border_color = GOLD_DIM
	st.content_margin_left = 12
	st.content_margin_right = 12
	st.content_margin_top = 1
	st.content_margin_bottom = 1
	box.add_theme_stylebox_override("panel", st)
	row.add_child(box)
	var v := Label.new()
	v.add_theme_font_size_override("font_size", 18)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.custom_minimum_size = Vector2(46, 0)
	box.add_child(v)
	return [panel, v]

func _build_top_left() -> void:
	var col := VBoxContainer.new()
	col.position = Vector2(MARGIN, MARGIN)
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	var turn := _info_panel("TURN")
	_turn_value = turn[1]
	_turn_value.text = "1"
	col.add_child(turn[0])

	var wave := _info_panel("WAVE")
	_wave_value = wave[1]
	col.add_child(wave[0])

	# "Name used": what the last action was. Fades out after a moment.
	var strip := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.09, 0.08, 0.07, 0.85)
	st.border_width_left = 3
	st.border_color = GOLD
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 3
	st.content_margin_bottom = 3
	strip.add_theme_stylebox_override("panel", st)
	strip.custom_minimum_size = Vector2(190, 0)
	strip.modulate.a = 0.0
	_name_used_panel = strip
	col.add_child(strip)
	_name_used = Label.new()
	_name_used.add_theme_font_size_override("font_size", 15)
	strip.add_child(_name_used)

	# Training mode: a reminder plus a way out (the battle never ends by itself).
	# Top-center, so it stays clear of the party figures on the left.
	if battle_manager.training:
		var box := VBoxContainer.new()
		box.anchor_left = 0.5
		box.anchor_right = 0.5
		box.offset_left = -105.0
		box.offset_right = 105.0
		box.offset_top = MARGIN
		box.add_theme_constant_override("separation", 4)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(box)
		var tag := Label.new()
		tag.text = "TRAINING  -  Energy is always full"
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.add_theme_font_size_override("font_size", 13)
		tag.add_theme_color_override("font_color", Color(0.55, 0.9, 0.85))
		box.add_child(tag)
		var exit_btn := Button.new()
		exit_btn.text = "Exit Training  (Esc)"
		exit_btn.custom_minimum_size = Vector2(0, 28)
		exit_btn.add_theme_font_size_override("font_size", 13)
		WorkshopStyle.style_button(exit_btn, 4)
		exit_btn.pressed.connect(func(): battle_manager.abort_battle())
		box.add_child(exit_btn)

func _build_enemy_panel() -> void:
	_enemy_panel = OrnatePanel.new()
	_enemy_panel.anchor_left = 1.0
	_enemy_panel.anchor_right = 1.0
	_enemy_panel.offset_right = -MARGIN
	_enemy_panel.offset_left = -MARGIN - 330.0
	_enemy_panel.offset_top = MARGIN
	_enemy_panel.grow_vertical = Control.GROW_DIRECTION_END
	_enemy_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_enemy_panel)
	_enemy_rows = VBoxContainer.new()
	_enemy_rows.add_theme_constant_override("separation", 4)
	_enemy_panel.add_child(_enemy_rows)

func _build_bottom() -> void:
	var total_h := 24.0 + PARTY_BAR_HEIGHT + 6.0 + ACTION_HEIGHT
	var bottom := VBoxContainer.new()
	bottom.anchor_left = 0.5
	bottom.anchor_right = 0.5
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_left = -BAR_WIDTH * 0.5
	bottom.offset_right = BAR_WIDTH * 0.5
	bottom.offset_bottom = -MARGIN
	bottom.offset_top = -MARGIN - total_h
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.add_theme_constant_override("separation", 3)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)

	# The row right above the party bar. Each party member gets a slot with
	# "<name>'s turn" (when it is theirs) and a small "Status" tab. The centered
	# label is only for enemy turns and the final result.
	var label_row := Control.new()
	label_row.custom_minimum_size = Vector2(0, 24)
	label_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(label_row)
	_slot_row = HBoxContainer.new()
	_slot_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slot_row.offset_left = 12
	_slot_row.offset_right = -12
	_slot_row.add_theme_constant_override("separation", 10)
	_slot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_row.add_child(_slot_row)
	_turn_label = Label.new()
	_turn_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_turn_label.add_theme_font_size_override("font_size", 19)
	_turn_label.add_theme_color_override("font_color", GOLD)
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_turn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_row.add_child(_turn_label)

	# Party status bar: one cell per character.
	var bar := OrnatePanel.new()
	bar.custom_minimum_size = Vector2(0, PARTY_BAR_HEIGHT)
	bar.corner_length = 16.0
	bottom.add_child(bar)
	_party_row = HBoxContainer.new()
	_party_row.add_theme_constant_override("separation", 10)
	bar.add_child(_party_row)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 3)
	bottom.add_child(spacer)

	# Action panel: categories | moves | targets.
	var actions := HBoxContainer.new()
	actions.custom_minimum_size = Vector2(0, ACTION_HEIGHT)
	actions.add_theme_constant_override("separation", 8)
	bottom.add_child(actions)

	var cat_panel := OrnatePanel.new()
	cat_panel.custom_minimum_size = Vector2(BAR_WIDTH * 0.22, 0)
	actions.add_child(cat_panel)
	_category_box = VBoxContainer.new()
	_category_box.add_theme_constant_override("separation", 3)
	cat_panel.add_child(_category_box)
	for c in CATEGORIES:
		var b := _make_category_button(c["label"], c["color"])
		var kind: String = c["kind"]
		b.focus_entered.connect(func(): _show_category(kind))
		b.pressed.connect(func(): _on_category_pressed(kind))
		_category_box.add_child(b)
		_category_buttons[kind] = b

	var move_panel := OrnatePanel.new()
	move_panel.custom_minimum_size = Vector2(BAR_WIDTH * 0.34, 0)
	move_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(move_panel)
	_move_scroll = ScrollContainer.new()
	_move_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_move_scroll.follow_focus = true
	move_panel.add_child(_move_scroll)
	_move_list = VBoxContainer.new()
	_move_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_move_list.add_theme_constant_override("separation", 3)
	_move_scroll.add_child(_move_list)

	var target_panel := OrnatePanel.new()
	target_panel.custom_minimum_size = Vector2(BAR_WIDTH * 0.40, 0)
	actions.add_child(target_panel)
	var tcol := VBoxContainer.new()
	tcol.add_theme_constant_override("separation", 4)
	target_panel.add_child(tcol)
	_target_title = Label.new()
	_target_title.add_theme_font_size_override("font_size", 14)
	_target_title.add_theme_color_override("font_color", GOLD)
	tcol.add_child(_target_title)
	_info_scroll = ScrollContainer.new()
	_info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_info_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info_scroll.custom_minimum_size = Vector2(0, 66)
	_info_scroll.visible = false
	tcol.add_child(_info_scroll)
	_info_body = Label.new()
	_info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_body.add_theme_font_size_override("font_size", 12)
	_info_scroll.add_child(_info_body)
	_target_grid = GridContainer.new()
	_target_grid.columns = 2
	_target_grid.add_theme_constant_override("h_separation", 6)
	_target_grid.add_theme_constant_override("v_separation", 4)
	_target_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tcol.add_child(_target_grid)
	_hint = Label.new()
	_hint.text = "Esc / right-click: back"
	_hint.add_theme_font_size_override("font_size", 11)
	_hint.modulate = Color(1, 1, 1, 0.45)
	_hint.size_flags_vertical = Control.SIZE_SHRINK_END
	tcol.add_child(_hint)

# ===========================================================================
# Party cells and enemy rows
# ===========================================================================

func _hook_unit(u: BattleUnit) -> void:
	u.hp_changed.connect(func(_unit, _hp): _update_unit(u))
	u.energy_changed.connect(func(_unit, _e): _update_unit(u))
	u.statuses_changed.connect(func(_unit): _update_unit(u))
	u.defeated.connect(func(_unit): _update_unit(u))

func _add_party_cell(u: BattleUnit) -> void:
	var cell := PanelContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cell.add_theme_stylebox_override("panel", _cell_style(false))
	_party_row.add_child(cell)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	cell.add_child(col)

	var top := HBoxContainer.new()
	col.add_child(top)
	var name_lbl := Label.new()
	name_lbl.text = u.stats.character_name
	name_lbl.add_theme_font_size_override("font_size", 15)
	top.add_child(name_lbl)
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 5)
	col.add_child(hp_row)
	hp_row.add_child(_small_label("HP"))
	var hp := StatBar.new()
	hp.fill_color = Color(0.3, 0.75, 0.35)
	hp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hp_row.add_child(hp)
	var hp_text := _small_label("")
	hp_text.custom_minimum_size = Vector2(30, 0)
	hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_row.add_child(hp_text)

	var ep_row := HBoxContainer.new()
	ep_row.add_theme_constant_override("separation", 5)
	col.add_child(ep_row)
	ep_row.add_child(_small_label("EP"))
	var ep := StatBar.new()
	ep.segments = BattleUnit.MAX_ENERGY
	ep.max_value = BattleUnit.MAX_ENERGY
	ep.fill_color = Color(0.95, 0.75, 0.2)
	ep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ep_row.add_child(ep)
	var ep_text := _small_label("")
	ep_text.custom_minimum_size = Vector2(30, 0)
	ep_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ep_row.add_child(ep_text)

	var slot := _make_status_slot(u)
	_party_cells[u] = {"panel": cell, "hp": hp, "hp_text": hp_text, "ep": ep, "ep_text": ep_text,
		"turn_label": slot["turn_label"], "tab": slot["tab"], "popup": slot["popup"], "popup_lines": slot["popup_lines"]}
	_update_unit(u, false)

## Dark-orange translucent box with the same gold border (Status tab + popup).
func _status_box_style(alpha: float) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.5, 0.22, 0.04, alpha)
	st.set_border_width_all(1)
	st.border_color = GOLD
	st.set_corner_radius_all(4)
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 1
	st.content_margin_bottom = 1
	return st

## One slot in the row above the party bar: "<name>'s turn" on the left and a
## small "Status" tab on the right. The tab only exists while the unit has a
## status; hovering it opens a small scrollable list.
func _make_status_slot(u: BattleUnit) -> Dictionary:
	var slot := HBoxContainer.new()
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_row.add_child(slot)

	var turn_label := Label.new()
	turn_label.add_theme_font_size_override("font_size", 17)
	turn_label.add_theme_color_override("font_color", GOLD)
	turn_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	turn_label.clip_text = true
	turn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(turn_label)

	var tab := PanelContainer.new()
	tab.add_theme_stylebox_override("panel", _status_box_style(0.7))
	tab.visible = false
	tab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.add_child(tab)
	var tab_label := Label.new()
	tab_label.text = "Status"
	tab_label.add_theme_font_size_override("font_size", 13)
	tab_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab.add_child(tab_label)

	# The list lives on the BattleUI itself (not inside the row) so it can float over the field.
	var popup := OrnatePanel.new() # same dark, gold-cornered box as the Guard description
	popup.custom_minimum_size = Vector2(290, 0)
	popup.corner_length = 8.0
	var pstyle := popup.get_theme_stylebox("panel") as StyleBoxFlat
	pstyle.content_margin_left = 10
	pstyle.content_margin_right = 10
	pstyle.content_margin_top = 6
	pstyle.content_margin_bottom = 6
	popup.visible = false
	popup.z_index = 30
	add_child(popup)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	popup.add_child(scroll)
	var lines := VBoxContainer.new()
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lines)
	return {"turn_label": turn_label, "tab": tab, "popup": popup, "popup_lines": lines}

func _process(_delta: float) -> void:
	# Show a unit's status list while the mouse is over its tab (or the list itself).
	var m := get_global_mouse_position()
	for u in _party_cells:
		var c: Dictionary = _party_cells[u]
		var tab: Control = c["tab"]
		var popup: Control = c["popup"]
		var over: bool = tab.visible and (tab.get_global_rect().has_point(m) or (popup.visible and popup.get_global_rect().has_point(m)))
		if over and not popup.visible:
			popup.visible = true
			_position_popup(u)
		elif not over and popup.visible:
			popup.visible = false

func _position_popup(u: BattleUnit) -> void:
	var c: Dictionary = _party_cells[u]
	var tab: Control = c["tab"]
	var popup: Control = c["popup"]
	popup.reset_size()
	var r := tab.get_global_rect()
	popup.global_position = Vector2(r.end.x - popup.size.x, r.position.y - popup.size.y - 2.0)

func _small_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	return l

func _cell_style(active: bool) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.16, 0.13, 0.07, 0.95) if active else Color(0.12, 0.11, 0.1, 0.9)
	st.set_border_width_all(2 if active else 1)
	st.border_color = GOLD if active else GOLD_DIM
	st.set_corner_radius_all(4)
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 3
	st.content_margin_bottom = 3
	return st

func _rebuild_enemy_list() -> void:
	for c in _enemy_rows.get_children():
		_enemy_rows.remove_child(c)
		c.queue_free()
	_enemy_cells.clear()
	# Regular enemies first, the boss last (like the sketch).
	var ordered: Array = battle_manager.enemy_team.filter(func(u): return not u.is_boss)
	ordered.append_array(battle_manager.enemy_team.filter(func(u): return u.is_boss))
	for u in ordered:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_enemy_rows.add_child(row)
		var name_lbl := Label.new()
		name_lbl.text = u.stats.character_name
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.custom_minimum_size = Vector2(136, 0)
		name_lbl.clip_text = true
		if u.is_boss:
			name_lbl.add_theme_color_override("font_color", GOLD)
		row.add_child(name_lbl)
		var bar := StatBar.new()
		bar.fill_color = Color(0.9, 0.55, 0.15) if u.is_boss else Color(0.85, 0.2, 0.2)
		bar.custom_minimum_size = Vector2(60, 14 if u.is_boss else 11)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var text := _small_label("")
		text.custom_minimum_size = Vector2(46, 0)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(text)
		_enemy_cells[u] = {"name": name_lbl, "bar": bar, "text": text}
		_update_unit(u, false)

func _on_wave_started(units: Array) -> void:
	for u in units:
		_hook_unit(u)
	_rebuild_enemy_list()
	_update_wave()

func _update_wave() -> void:
	_wave_value.text = "%d/%d" % [battle_manager.current_wave, battle_manager.wave_count]

## Refreshes one unit's bars and text (party cell or enemy row).
func _update_unit(u: BattleUnit, animate: bool = true) -> void:
	if _party_cells.has(u):
		var c: Dictionary = _party_cells[u]
		c["hp"].set_target(u.current_health, u.stats.max_health, animate)
		c["hp_text"].text = str(u.current_health)
		c["ep"].set_target(u.current_energy, BattleUnit.MAX_ENERGY, animate)
		c["ep_text"].text = "%d/%d" % [u.current_energy, BattleUnit.MAX_ENERGY]
		_update_status_box(c, u)
		c["panel"].modulate = Color.WHITE if u.is_alive() else Color(0.5, 0.5, 0.5, 0.8)
	elif _enemy_cells.has(u):
		var c: Dictionary = _enemy_cells[u]
		c["bar"].set_target(u.current_health, u.stats.max_health, animate)
		c["text"].text = str(u.current_health) if u.is_alive() else "KO"
		c["name"].modulate = Color.WHITE if u.is_alive() else Color(0.5, 0.5, 0.5, 0.8)

func _update_status_box(c: Dictionary, u: BattleUnit) -> void:
	var details := u.status_details()
	c["tab"].visible = details.size() > 0 and u.is_alive()
	var box: VBoxContainer = c["popup_lines"]
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	for d in details:
		var title := Label.new()
		title.text = d[0]
		title.add_theme_font_size_override("font_size", 14)
		title.add_theme_color_override("font_color", GOLD)
		box.add_child(title)
		var body := Label.new()
		body.text = d[1]
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(250, 0)
		body.add_theme_font_size_override("font_size", 12)
		box.add_child(body)
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 4)
		box.add_child(gap)
	var scroll: ScrollContainer = box.get_parent()
	# about two entries show at once; the mouse wheel scrolls the rest
	scroll.custom_minimum_size = Vector2(0, 0 if details.is_empty() else (68 if details.size() == 1 else 136))
	if not c["tab"].visible:
		c["popup"].visible = false
	elif c["popup"].visible:
		_position_popup(u)

## Highlights the acting unit's cell and shows "<name>'s turn" right above it.
func _highlight_active(unit: BattleUnit) -> void:
	for u in _party_cells:
		_party_cells[u]["panel"].add_theme_stylebox_override("panel", _cell_style(u == unit))
		_party_cells[u]["turn_label"].text = "%s's turn" % u.stats.character_name if u == unit else ""

# ===========================================================================
# Turn flow
# ===========================================================================

func _on_enemy_turn(u: BattleUnit) -> void:
	_current_unit = null
	_highlight_active(null)
	_clear_actions()
	_turn_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.45))
	_turn_label.text = "%s is acting..." % u.stats.character_name

func _on_battle_ended(player_won: bool) -> void:
	_clear_actions()
	_highlight_active(null)
	_turn_label.add_theme_color_override("font_color", GOLD)
	if battle_manager.training:
		_turn_label.text = "TRAINING ENDED"
	else:
		_turn_label.text = "VICTORY" if player_won else "DEFEAT"

func _on_action_announced(user: BattleUnit, action_name: String) -> void:
	_name_used.text = "%s  >  %s" % [user.stats.character_name, action_name]
	_name_used_panel.modulate.a = 1.0
	if _name_tween:
		_name_tween.kill()
	_name_tween = create_tween()
	_name_tween.tween_interval(1.6)
	_name_tween.tween_property(_name_used_panel, "modulate:a", 0.0, 0.5)

func _on_player_turn(unit: BattleUnit, actions: Dictionary) -> void:
	_current_unit = unit
	_current_actions = actions
	_turn_label.text = "" # the per-unit label above the party bar says whose turn it is
	_highlight_active(unit)
	_show_categories()

func _clear_actions() -> void:
	_on_cancel = Callable()
	_picking_target = false
	_hide_info()
	_clear_children(_move_list)
	_clear_children(_target_grid)
	_target_title.text = ""
	_hint.visible = false
	for b in _category_buttons.values():
		b.disabled = true
	target_focused.emit([])

func _clear_children(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()

## Back to the category list (start of every turn, and Esc from the move list).
func _show_categories() -> void:
	_picking_target = false
	_hide_info()
	_clear_children(_move_list)
	_clear_children(_target_grid)
	_target_title.text = ""
	_hint.visible = false
	target_focused.emit([])
	_on_cancel = Callable()
	for b in _category_buttons.values():
		b.disabled = false
	var first: Button = _category_buttons[_kind] if _category_buttons.has(_kind) else _category_buttons["basic"]
	if first.has_focus():
		_show_category(_kind)
	else:
		first.grab_focus() # focus_entered fills the middle panel

## Fills the middle panel for a category (called when its button gets focus).
func _show_category(kind: String) -> void:
	if _current_unit == null:
		return
	_kind = kind
	_picking_target = false
	_hide_info()
	_clear_children(_move_list)
	_clear_children(_target_grid)
	_target_title.text = ""
	target_focused.emit([])
	match kind:
		"basic":
			for move in _current_actions["basic"]:
				_add_entry(move.move_name, func(): _select_targets("basic", move, null), true, move.move_name, _move_info(move))
		"alteration":
			for move in _current_actions["alteration"]:
				var label: String = move.move_name + "   %d EN" % _current_unit.energy_cost_for(move)
				var left: int = _current_unit.uses_left(move)
				if left >= 0:
					label += "   [%d left]" % left
				_add_entry(label, func(): _select_targets("alteration", move, null), true, move.move_name, _move_info(move))
			for move in _current_actions.get("locked_alteration", []):
				var why := "needs %d EN" % _current_unit.energy_cost_for(move)
				if _current_unit.uses_left(move) == 0:
					why = "no uses left"
				_add_entry("%s   (%s)" % [move.move_name, why], Callable(), false, move.move_name, _move_info(move))
		"item":
			var items: Array = _current_actions["items"]
			if items.is_empty():
				_add_entry("(no items)", Callable(), false)
			for item in items:
				var qty: int = battle_manager.party_inventory[item]
				_add_entry("%s  x%d" % [item.item_name, qty], func(): _select_targets("item", null, item), true, item.item_name, item.description)
		"guard":
			var l := Label.new()
			l.text = "Guard\nHalves damage taken until the next round.\n+1 Energy at the start of your next turn."
			l.add_theme_font_size_override("font_size", 13)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_move_list.add_child(l)

func _on_category_pressed(kind: String) -> void:
	if _current_unit == null:
		return
	if kind == "guard":
		_submit("guard", null, null, [])
		return
	_show_category(kind)
	var btn := _first_button(_move_list)
	if btn:
		_on_cancel = _show_categories
		btn.grab_focus()
		_hint.visible = true

## info_title / info_body: what the right-hand box shows while this entry is hovered or focused.
func _add_entry(text: String, callback: Callable, enabled: bool = true, info_title: String = "", info_body: String = "") -> void:
	var btn := _make_gold_button(text)
	btn.disabled = not enabled
	if enabled:
		btn.pressed.connect(callback)
	if info_title != "":
		btn.focus_entered.connect(func(): _show_info(info_title, info_body))
		btn.mouse_entered.connect(func(): _show_info(info_title, info_body))
	_move_list.add_child(btn)

func _show_info(title: String, body: String) -> void:
	if _picking_target:
		return
	_target_title.text = title
	_info_body.text = body
	_info_scroll.visible = true
	_target_grid.visible = false
	_hint.visible = false # more room for the text; the hint returns with the target list

func _hide_info() -> void:
	_info_scroll.visible = false
	_target_grid.visible = true

## Live numbers for a move, from the unit's current (buffed) stats.
func _unit_stats() -> Dictionary:
	return {"attack": _current_unit.get_attack(), "capability": _current_unit.get_capability(), "speed": _current_unit.get_speed()}

func _move_info(move: Move) -> String:
	var t := move.description
	if move.formula != "":
		t += "\nHitungan: " + move.formula
	var live := ""
	if move.skill_id != "":
		var sk := SkillLibrary.get_skill(move.skill_id)
		if sk != null:
			live = sk.preview_text(_unit_stats())
	elif move.deals_damage:
		var s := _unit_stats()
		live = "Saat ini: %d damage" % move.damage_per_hit(s["attack"], s["capability"], s["speed"])
	if live != "":
		t += "\n" + live
	return t

## Target step: one button per candidate in a 2-column grid (like the field).
func _select_targets(kind: String, move: Move, item: Item) -> void:
	var candidates: Array = []
	var target_all := false
	var enemy_side := false

	if kind == "item":
		candidates = battle_manager.player_team.filter(func(u): return item.revive or u.is_alive())
	elif move.target_type == Move.Target.SELF:
		_submit(kind, move, item, [_current_unit])
		return
	elif move.target_type in [Move.Target.SINGLE_ENEMY, Move.Target.ALL_ENEMIES]:
		candidates = battle_manager.enemy_team.filter(func(u): return u.is_alive())
		target_all = move.target_type == Move.Target.ALL_ENEMIES
		enemy_side = true
	else:
		candidates = battle_manager.player_team.filter(func(u): return u.is_alive())
		target_all = move.target_type == Move.Target.ALL_ALLIES

	if target_all:
		_submit(kind, move, item, candidates)
		return

	var came_from: Control = get_viewport().gui_get_focus_owner()
	if came_from is Button:
		came_from.add_theme_stylebox_override("normal", _gold_picked_style()) # stays gold while picking a target
	_clear_children(_target_grid)
	_picking_target = true
	_hide_info()
	_hint.visible = true
	_target_title.text = "Target who?"
	_on_cancel = func():
		_picking_target = false
		if is_instance_valid(came_from) and came_from is Button:
			came_from.add_theme_stylebox_override("normal", _gold_normal_style())
		_clear_children(_target_grid)
		_target_title.text = ""
		target_focused.emit([])
		_on_cancel = _show_categories
		if is_instance_valid(came_from):
			came_from.grab_focus() # focus_entered brings the move's description back
	for target in candidates:
		var btn := _make_gold_button(target.stats.character_name)
		btn.custom_minimum_size = Vector2(0, 26)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.focus_entered.connect(func(): target_focused.emit([target]))
		btn.mouse_entered.connect(func(): target_focused.emit([target]))
		btn.pressed.connect(func(): _submit(kind, move, item, [target]))
		_target_grid.add_child(btn)
	var first := _first_button(_target_grid)
	if first:
		first.grab_focus()

func _submit(kind: String, move: Move, item: Item, targets: Array) -> void:
	_clear_actions()
	var action_data := {"type": kind, "targets": targets}
	if move:
		action_data["move"] = move
	if item:
		action_data["item"] = item
	battle_manager.submit_player_action(action_data)

func _first_button(root: Node) -> Button:
	for c in root.get_children():
		if c is Button and not c.disabled and not c.is_queued_for_deletion():
			return c
	return null

## Esc / right-click = back one step.
func _unhandled_input(event: InputEvent) -> void:
	var back := event.is_action_pressed("ui_cancel")
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		back = true
	if back and _on_cancel.is_valid():
		_on_cancel.call()
		get_viewport().set_input_as_handled()
	elif back and battle_manager.training and _current_unit != null:
		battle_manager.abort_battle() # Esc at the top level leaves Training
		get_viewport().set_input_as_handled()

# ===========================================================================
# Button looks
# ===========================================================================

func _flat(bg: Color, border: Color, border_w: int, radius: int = 3) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.set_border_width_all(border_w)
	st.set_corner_radius_all(radius)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 2
	st.content_margin_bottom = 2
	return st

## Category bar (ATTACK / ALTERATION / ITEM / GUARD): flat colour, gold frame when selected.
func _make_category_button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 24)
	b.add_theme_font_size_override("font_size", 14)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var normal := _flat(color.darkened(0.15), color.lightened(0.2), 1)
	var focus := _flat(color, GOLD, 3)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", _flat(color, color.lightened(0.4), 2))
	b.add_theme_stylebox_override("pressed", focus)
	b.add_theme_stylebox_override("focus", focus)
	b.add_theme_stylebox_override("disabled", _flat(color.darkened(0.6), color.darkened(0.3), 1))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.4))
	return b

func _gold_normal_style() -> StyleBoxFlat:
	return _flat(Color(0.14, 0.12, 0.09), GOLD_DIM, 1, 6)

func _gold_picked_style() -> StyleBoxFlat:
	return _flat(Color(0.9, 0.7, 0.15), Color(1.0, 0.92, 0.5), 2, 6)

## Move / target button: outlined, turns solid gold when selected.
func _make_gold_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 25)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 14)
	var normal := _gold_normal_style()
	var picked := _gold_picked_style()
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", picked)
	b.add_theme_stylebox_override("pressed", picked)
	b.add_theme_stylebox_override("focus", picked)
	b.add_theme_stylebox_override("disabled", _flat(Color(0.1, 0.09, 0.08), Color(0.25, 0.22, 0.15), 1, 6))
	b.add_theme_color_override("font_focus_color", TEXT_DARK)
	b.add_theme_color_override("font_hover_color", TEXT_DARK)
	b.add_theme_color_override("font_pressed_color", TEXT_DARK)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	return b
