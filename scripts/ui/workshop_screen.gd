extends Control
class_name WorkshopScreen
## Admin's workshop: spend Shangri-La Fragments to craft weapon upgrades.
## Crafting a weapon equips it, replacing the character's current one. Owned
## weapons can be swapped back at any time for free.
## Emits `changed` whenever the GameState was modified (so it can be saved).

signal back_pressed
signal changed

var _state: GameState
var _selected_id: String = ""

var _fragments_label: Label
var _list: VBoxContainer
var _admin_label: Label
var _char_buttons: Array[Button] = []
var _back_btn: Button

func _ready() -> void:
	var screen := get_viewport_rect().size
	position = Vector2.ZERO
	size = screen

	var center := CenterContainer.new()
	center.size = screen
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(880, 0)
	panel.add_theme_stylebox_override("panel", _rect_style(12))
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	var title := Label.new()
	title.text = "ADMIN'S WORKSHOP"
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	_fragments_label = Label.new()
	_fragments_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_fragments_label)

	var char_row := HBoxContainer.new()
	char_row.alignment = BoxContainer.ALIGNMENT_CENTER
	char_row.add_theme_constant_override("separation", 10)
	col.add_child(char_row)

	var group := ButtonGroup.new()
	var defs := Roster.all()
	_selected_id = defs[0].id
	for d in defs:
		var b := Button.new()
		b.text = d.display_name
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(150, 44)
		b.button_pressed = d.id == _selected_id
		b.pressed.connect(func():
			_selected_id = d.id
			_rebuild()
		)
		char_row.add_child(b)
		_char_buttons.append(b)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	col.add_child(_list)

	_admin_label = Label.new()
	_admin_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_admin_label.custom_minimum_size = Vector2(0, 28)
	_admin_label.modulate = Roster.ADMIN_COLOR.lightened(0.4)
	col.add_child(_admin_label)

	_back_btn = Button.new()
	_back_btn.text = "Back to Lobby"
	_back_btn.custom_minimum_size = Vector2(0, 48)
	_back_btn.pressed.connect(func(): back_pressed.emit())
	col.add_child(_back_btn)

func refresh(state: GameState) -> void:
	_state = state
	_admin_label.text = ""
	_rebuild()

func focus_first() -> void:
	for c in _list.get_children():
		for b in c.get_children():
			if b is Button and not b.disabled:
				b.grab_focus()
				return
	_back_btn.grab_focus()

func _rebuild() -> void:
	if _state == null:
		return
	_fragments_label.text = "Shangri-La Fragments: %d" % _state.fragments

	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()

	var equipped_id := _state.equipped_id(_selected_id)
	for w in GearLibrary.for_character(_selected_id):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)

		var info := Label.new()
		info.text = "%s   (%s)\n%s" % [w.display_name, w.bonus_text(), w.description]
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.custom_minimum_size = Vector2(560, 0)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(180, 56)
		if w.id == equipped_id:
			btn.text = "Equipped"
			btn.disabled = true
		elif _state.owns(w.id):
			btn.text = "Equip"
			btn.pressed.connect(func(): _on_equip(w))
		else:
			btn.text = "Craft (%d)" % w.cost
			btn.disabled = not _state.can_afford(w.cost)
			btn.pressed.connect(func(): _on_craft(w))
		row.add_child(btn)
		_list.add_child(row)

func _on_craft(w: Weapon) -> void:
	if _state.buy_weapon(w):
		_admin_label.text = "Admin: %s is ready. It's yours." % w.display_name # placeholder line
		changed.emit()
	_rebuild()
	focus_first.call_deferred()

func _on_equip(w: Weapon) -> void:
	if _state.equip(_selected_id, w.id):
		_admin_label.text = "Admin: Swapped to %s." % w.display_name # placeholder line
		changed.emit()
	_rebuild()
	focus_first.call_deferred()

func _rect_style(corner_radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	style.set_border_width_all(3)
	style.border_color = Color(1, 1, 1, 0.85)
	style.set_corner_radius_all(corner_radius)
	style.set_content_margin_all(24)
	return style
