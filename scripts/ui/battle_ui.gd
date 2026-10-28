extends Control
class_name BattleUI
## Reference UI, builds itself in code.
## Layout, top to bottom: battle log strip (top), enemy HP panel
## (top-right), then everything else stacked in the bottom third of the
## screen - party status row, then the action menu band underneath it.
## Action menu: main = 4 uniform colored squares; any submenu = one
## bordered rectangle panel holding a plain button list.

@export var battle_manager: BattleManager

const LOG_HEIGHT := 110.0
const ACTION_MENU_HEIGHT := 170.0
const PARTY_ROW_HEIGHT := 90.0
const BAND_GAP := 10.0

var log_label: RichTextLabel
var actions_container: VBoxContainer
var party_status: HBoxContainer
var enemy_status: VBoxContainer

var _current_unit: BattleUnit
var _current_actions: Dictionary
var _active_list: Container # where _add_button() appends; set per submenu
var _on_cancel: Callable # what Esc does in the current menu (empty = nothing)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_layout()

	battle_manager.battle_log.connect(_on_log)
	battle_manager.player_turn_started.connect(_on_player_turn)
	battle_manager.enemy_turn_started.connect(func(u):
		log_label.clear()
		_on_log("[%s is acting...]" % u.stats.character_name)
	)
	battle_manager.battle_ended.connect(_on_battle_ended)
	battle_manager.wave_started.connect(_on_wave_started)

	for u in battle_manager.player_team:
		u.hp_changed.connect(func(_unit, _hp): _refresh_status())
		u.energy_changed.connect(func(_unit, _e): _refresh_status())
		u.statuses_changed.connect(func(_unit): _refresh_status())
	for u in battle_manager.enemy_team:
		u.hp_changed.connect(func(_unit, _hp): _refresh_status())
		u.statuses_changed.connect(func(_unit): _refresh_status())

	_refresh_status()
	battle_manager.start_battle()

func _on_wave_started(units: Array) -> void:
	for u in units:
		u.hp_changed.connect(func(_unit, _hp): _refresh_status())
		u.statuses_changed.connect(func(_unit): _refresh_status())
	_refresh_status()

func _build_layout() -> void:
	# Plain pixel math, not anchors - placed directly from the actual
	# viewport size so there's no anchor/offset math to get subtly wrong.
	var screen := get_viewport_rect().size

	# Battle log - fixed strip, top, full width.
	var log_panel := PanelContainer.new()
	log_panel.position = Vector2.ZERO
	log_panel.size = Vector2(screen.x, LOG_HEIGHT)
	add_child(log_panel)
	log_label = RichTextLabel.new()
	log_label.scroll_following = true
	log_label.bbcode_enabled = false
	log_label.add_theme_font_size_override("normal_font_size", 14)
	log_panel.add_child(log_label)

	# Enemy HP - bordered rounded panel, top-right corner.
	const ENEMY_PANEL_WIDTH := 320.0
	const ENEMY_PANEL_MARGIN := 24.0
	var enemy_panel := PanelContainer.new()
	enemy_panel.position = Vector2(screen.x - ENEMY_PANEL_WIDTH - ENEMY_PANEL_MARGIN, ENEMY_PANEL_MARGIN)
	enemy_panel.size = Vector2(ENEMY_PANEL_WIDTH, 0)
	enemy_panel.add_theme_stylebox_override("panel", _rect_style(12))
	add_child(enemy_panel)
	enemy_status = VBoxContainer.new()
	enemy_panel.add_child(enemy_status)

	# Party row - fixed band, directly above the action menu band.
	party_status = HBoxContainer.new()
	party_status.position = Vector2(0, screen.y - ACTION_MENU_HEIGHT - BAND_GAP - PARTY_ROW_HEIGHT)
	party_status.size = Vector2(screen.x, PARTY_ROW_HEIGHT)
	party_status.alignment = BoxContainer.ALIGNMENT_CENTER
	party_status.add_theme_constant_override("separation", 32)
	add_child(party_status)

	# Action menu - fixed band, flush with the bottom of the screen.
	var action_band := CenterContainer.new()
	action_band.position = Vector2(0, screen.y - ACTION_MENU_HEIGHT)
	action_band.size = Vector2(screen.x, ACTION_MENU_HEIGHT)
	add_child(action_band)
	actions_container = VBoxContainer.new()
	actions_container.alignment = BoxContainer.ALIGNMENT_CENTER
	action_band.add_child(actions_container)

func _on_log(text: String) -> void:
	log_label.append_text(text + "\n")

func _on_battle_ended(player_won: bool) -> void:
	_clear_actions()
	_on_log("=== %s ===" % ("YOU WIN" if player_won else "GAME OVER"))

func _on_player_turn(unit: BattleUnit, actions: Dictionary) -> void:
	_current_unit = unit
	_current_actions = actions
	log_label.clear()
	_on_log("It's %s's turn." % unit.stats.character_name)
	_show_main_menu()

func _clear_actions() -> void:
	_on_cancel = Callable() # each menu sets its own after clearing
	for c in actions_container.get_children():
		c.queue_free()

## Esc (ui_cancel) = go back one menu, same as the Back button.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _on_cancel.is_valid():
		_on_cancel.call()
		get_viewport().set_input_as_handled()

## Keyboard support: after every menu rebuild, put focus on the first usable
## button. Arrow keys then move between options and Space (ui_accept)
## presses the focused one. Mouse clicks keep working as before.
func _grab_first_focus() -> void:
	var btn := _find_first_button(actions_container)
	if btn:
		btn.grab_focus()

func _find_first_button(root: Node) -> Button:
	for c in root.get_children():
		if c.is_queued_for_deletion():
			continue # old menu nodes are still in the tree until end of frame
		if c is Button and not c.disabled:
			return c
		var found := _find_first_button(c)
		if found:
			return found
	return null

## Main menu: the 4 uniform colored squares, floating directly in the
## bottom band (no outer panel).
func _show_main_menu() -> void:
	_clear_actions()
	_active_list = actions_container

	var title := Label.new()
	title.text = "%s's turn" % _current_unit.stats.character_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	actions_container.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	actions_container.add_child(row)

	# Order: Basic -> Alteration -> Guard -> Item, left to right.
	row.add_child(_make_category_box(
		"Basic", Color(0.78, 0.18, 0.22), func(): _show_move_menu("basic")
	))
	row.add_child(_make_category_box(
		"Alteration", Color(0.5, 0.22, 0.72), func(): _show_move_menu("alteration")
	))
	row.add_child(_make_category_box(
		"Guard", Color(0.2, 0.62, 0.28),
		func(): _submit("guard", null, null, [])
	))
	row.add_child(_make_category_box(
		"Item", Color(0.5, 0.22, 0.72), func(): _show_item_menu()
	))
	_grab_first_focus.call_deferred()

## Any submenu (moves/items/targets): a single bordered rectangle panel
## holding a plain vertical button list. Replaces the colored squares
## entirely (actions_container was already cleared above/by caller).
func _open_submenu_panel() -> void:
	var panel := PanelContainer.new()
	var style := _rect_style(10)
	style.set_content_margin_all(8) # tighter than the default so more rows fit
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(300, 0)
	actions_container.add_child(panel)

	# Scrolls when there are more rows than fit in the bottom band;
	# follow_focus keeps the keyboard-selected row visible.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, ACTION_MENU_HEIGHT - 24)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	panel.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	_active_list = list

func _show_move_menu(kind: String) -> void:
	_clear_actions()
	_open_submenu_panel()
	_on_cancel = _show_main_menu

	var moves: Array = _current_actions[kind]
	for move in moves:
		var label: String = move.move_name
		if kind == "alteration":
			label += " (%d energy)" % _current_unit.energy_cost_for(move)
			var left: int = _current_unit.uses_left(move)
			if left >= 0:
				label += " [%d left]" % left
		_add_button(label, func(): _select_targets(kind, move, null))

	if kind == "alteration":
		for move in _current_actions.get("locked_alteration", []):
			# Say WHY it's locked: out of uses, or not enough energy.
			var why := "needs %d energy" % _current_unit.energy_cost_for(move)
			if _current_unit.uses_left(move) == 0:
				why = "no uses left"
			_add_button("%s (%s)" % [move.move_name, why], func(): pass, false)

	_add_button("Back", func(): _show_main_menu())
	_grab_first_focus.call_deferred()

func _show_item_menu() -> void:
	_clear_actions()
	_open_submenu_panel()
	_on_cancel = _show_main_menu

	var items: Array = _current_actions["items"]
	if items.is_empty():
		_add_button("(no items)", func(): pass, false)
	for item in items:
		var qty: int = battle_manager.party_inventory[item]
		_add_button("%s x%d" % [item.item_name, qty], func(): _select_targets("item", null, item))
	_add_button("Back", func(): _show_main_menu())
	_grab_first_focus.call_deferred()

func _select_targets(kind: String, move: Move, item: Item) -> void:
	_clear_actions()
	_open_submenu_panel()
	# Esc / Back returns to the menu we came from (not all the way to main).
	if kind == "item":
		_on_cancel = _show_item_menu
	else:
		_on_cancel = _show_move_menu.bind(kind)

	var candidates: Array = []
	var target_all := false

	if kind == "item":
		candidates = battle_manager.player_team.filter(func(u): return item.revive or u.is_alive())
	elif move.target_type == Move.Target.SELF:
		# Self-targeted moves (e.g. Strengthen) never ask for a target.
		_submit(kind, move, item, [_current_unit])
		return
	elif move.target_type in [Move.Target.SINGLE_ENEMY, Move.Target.ALL_ENEMIES]:
		candidates = battle_manager.enemy_team.filter(func(u): return u.is_alive())
		target_all = move.target_type == Move.Target.ALL_ENEMIES
	else:
		candidates = battle_manager.player_team.filter(func(u): return u.is_alive())
		target_all = move.target_type == Move.Target.ALL_ALLIES

	if target_all:
		_submit(kind, move, item, candidates)
		return

	for target in candidates:
		_add_button(target.stats.character_name, func(): _submit(kind, move, item, [target]))
	_add_button("Back", _on_cancel)
	_grab_first_focus.call_deferred()

func _submit(kind: String, move: Move, item: Item, targets: Array) -> void:
	_on_cancel = Callable() # action is chosen; Esc does nothing until the next menu
	var action_data := {"type": kind, "targets": targets}
	if move:
		action_data["move"] = move
	if item:
		action_data["item"] = item
	battle_manager.submit_player_action(action_data)

func _add_button(text: String, callback: Callable, enabled: bool = true) -> void:
	var btn := Button.new()
	btn.text = text
	btn.disabled = not enabled
	btn.pressed.connect(callback)
	_active_list.add_child(btn)

## A single uniform, colored, rounded category box (placeholder for real
## icon art) with its name as a caption label underneath - not drawn
## inside the box itself. Every box is the same size on purpose.
func _make_category_box(text: String, color: Color, callback: Callable) -> Control:
	var box_entry := VBoxContainer.new()
	box_entry.alignment = BoxContainer.ALIGNMENT_CENTER

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(84, 84)
	btn.pressed.connect(callback)

	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(14)
	style.set_border_width_all(3)
	style.border_color = Color(1, 1, 1, 0.85)
	# Focused box gets a yellow border so keyboard users can see the selection.
	var focus_style := style.duplicate() as StyleBoxFlat
	focus_style.border_color = Color(1.0, 0.9, 0.2)
	focus_style.set_border_width_all(5)
	for state in ["normal", "hover", "pressed"]:
		btn.add_theme_stylebox_override(state, style)
	btn.add_theme_stylebox_override("focus", focus_style)
	box_entry.add_child(btn)

	var caption := Label.new()
	caption.text = text
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box_entry.add_child(caption)

	return box_entry

## Shared bordered-rectangle look for panels (enemy HP box, submenu box).
func _rect_style(corner_radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	style.set_border_width_all(3)
	style.border_color = Color(1, 1, 1, 0.85)
	style.set_corner_radius_all(corner_radius)
	style.set_content_margin_all(16)
	return style

func _refresh_status() -> void:
	for c in party_status.get_children():
		c.queue_free()
	for u in battle_manager.player_team:
		var entry := VBoxContainer.new()
		entry.alignment = BoxContainer.ALIGNMENT_CENTER

		var hp_text := "%d/%d" % [u.current_health, u.stats.max_health] if u.is_alive() else "KO"
		var hp_lbl := Label.new()
		hp_lbl.text = "HP %s   EN %d/%d" % [hp_text, u.current_energy, BattleUnit.MAX_ENERGY]
		hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		entry.add_child(hp_lbl)

		var name_lbl := Label.new()
		name_lbl.text = u.stats.character_name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		entry.add_child(name_lbl)

		var status_txt := u.status_text()
		if status_txt != "":
			var st_lbl := Label.new()
			st_lbl.text = status_txt
			st_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			st_lbl.add_theme_font_size_override("font_size", 12)
			st_lbl.modulate = Color(1.0, 0.85, 0.4)
			entry.add_child(st_lbl)

		party_status.add_child(entry)

	for c in enemy_status.get_children():
		c.queue_free()
	if battle_manager.wave_count > 1:
		var wave_lbl := Label.new()
		wave_lbl.text = "Wave %d / %d" % [battle_manager.current_wave, battle_manager.wave_count]
		wave_lbl.modulate = Color(1, 1, 1, 0.6)
		enemy_status.add_child(wave_lbl)
	for u in battle_manager.enemy_team:
		var lbl := Label.new()
		var hp_text := "%d/%d" % [u.current_health, u.stats.max_health] if u.is_alive() else "KO"
		lbl.text = "%s  HP %s" % [u.stats.character_name, hp_text]
		if u.is_alive() and u.status_text() != "":
			lbl.text += "   [%s]" % u.status_text()
		enemy_status.add_child(lbl)
