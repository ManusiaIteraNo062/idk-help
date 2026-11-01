extends Control
class_name EquipmentWorkshop
## Workshop > Equipment. Three tabs, one character row, and the same
## craft / equip / unequip buttons everywhere:
##   Upgrades        - one active upgrade per character (stat bonuses)
##   Equipment       - 5 slots per character, each character crafts their own copy
##   Skill Knowledge - learn unlockable Alterations; shows what each skill does
## Emits `changed` whenever the GameState was modified (so it can be saved).

signal back_pressed
signal changed

enum Mode { UPGRADES, EQUIPMENT, SKILLS }

var _state: GameState
var _selected_id: String = ""
var _mode: Mode = Mode.UPGRADES
var _focus_row: int = 0 # keep the cursor on the same row after pressing a button

var _fragments_label: Label
var _header_label: Label
var _list: VBoxContainer
var _admin_label: Label
var _back_btn: Button
var _mode_buttons: Array[Button] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var frame := WorkshopStyle.build_frame(880)
	center.add_child(frame["root"])
	var col: VBoxContainer = frame["content"]
	col.add_theme_constant_override("separation", 7)

	col.add_child(WorkshopStyle.title_label("EQUIPMENT", 24))

	_fragments_label = Label.new()
	_fragments_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_fragments_label)

	# --- tab row: Upgrades | Equipment | Skill Knowledge ---
	var mode_row := HBoxContainer.new()
	mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_row.add_theme_constant_override("separation", 10)
	col.add_child(mode_row)
	var mode_group := ButtonGroup.new()
	var mode_names := ["Upgrades", "Equipment", "Skill Knowledge"]
	for i in mode_names.size():
		var b := Button.new()
		b.text = mode_names[i]
		b.toggle_mode = true
		b.button_group = mode_group
		b.custom_minimum_size = Vector2(200, 42)
		b.button_pressed = i == _mode
		WorkshopStyle.style_button(b)
		var mode_value: Mode = i
		b.pressed.connect(func():
			_mode = mode_value
			_focus_row = 0
			_rebuild()
		)
		mode_row.add_child(b)
		_mode_buttons.append(b)

	# --- character row ---
	var char_row := HBoxContainer.new()
	char_row.alignment = BoxContainer.ALIGNMENT_CENTER
	char_row.add_theme_constant_override("separation", 10)
	col.add_child(char_row)
	var char_group := ButtonGroup.new()
	var defs := Roster.all()
	_selected_id = defs[0].id
	for d in defs:
		var b := Button.new()
		b.text = d.display_name
		b.toggle_mode = true
		b.button_group = char_group
		b.custom_minimum_size = Vector2(150, 42)
		b.button_pressed = d.id == _selected_id
		WorkshopStyle.style_button(b)
		b.pressed.connect(func():
			_selected_id = d.id
			_focus_row = 0
			_rebuild()
		)
		char_row.add_child(b)

	_header_label = Label.new()
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.modulate = Color(1, 1, 1, 0.75)
	col.add_child(_header_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 224)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	_admin_label = Label.new()
	_admin_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_admin_label.custom_minimum_size = Vector2(0, 26)
	_admin_label.modulate = Roster.ADMIN_COLOR.lightened(0.4)
	col.add_child(_admin_label)

	_back_btn = Button.new()
	_back_btn.text = "Back"
	_back_btn.custom_minimum_size = Vector2(0, 42)
	WorkshopStyle.style_button(_back_btn)
	_back_btn.pressed.connect(func(): back_pressed.emit())
	col.add_child(_back_btn)

func refresh(state: GameState) -> void:
	_state = state
	_admin_label.text = ""
	_focus_row = 0
	_rebuild()

## Puts the cursor on the button of row `_focus_row` (or the nearest enabled one).
func focus_first() -> void:
	var rows := _list.get_children()
	if rows.is_empty():
		_back_btn.grab_focus()
		return
	var start := clampi(_focus_row, 0, rows.size() - 1)
	var order: Array[int] = []
	for i in range(start, rows.size()):
		order.append(i)
	for i in range(start - 1, -1, -1):
		order.append(i)
	for i in order:
		for b in rows[i].get_children():
			if b is Button and not b.disabled:
				b.grab_focus()
				return
	_back_btn.grab_focus()

func _rebuild() -> void:
	if _state == null:
		return
	_fragments_label.text = "Shangri-La Fragments: %d" % _state.fragments

	var st := _state.stats_for(_selected_id)
	var header := "HP %d   STR %d   CAP %d   SPD %d" % [st["health"], st["attack"], st["capability"], st["speed"]]
	if _mode == Mode.EQUIPMENT:
		header += "      Slot terpakai: %d / %d" % [_state.gear_slots_used(_selected_id), GearLibrary.SLOTS]
	_header_label.text = header

	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()

	match _mode:
		Mode.UPGRADES:
			_build_upgrades()
		Mode.EQUIPMENT:
			_build_equipment()
		Mode.SKILLS:
			_build_skills(st)

func _row(text: String, button_text: String, disabled: bool, on_press: Callable) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", WorkshopStyle.card_style())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)

	var info := Label.new()
	info.text = text
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(540, 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(170, 52)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.text = button_text
	btn.disabled = disabled
	WorkshopStyle.style_button(btn)
	var index := _list.get_child_count()
	if not disabled:
		btn.pressed.connect(func():
			_focus_row = index
			on_press.call()
		)
	row.add_child(btn)
	_list.add_child(card)

# ---- Upgrades ----------------------------------------------------------

func _build_upgrades() -> void:
	var equipped_id := _state.equipped_id(_selected_id)
	for u in GearLibrary.upgrades_for(_selected_id):
		var text := "%s   (%s)\n%s" % [u.display_name, u.bonus_text(), u.description]
		if u.id == equipped_id:
			_row(text, "Equipped", true, Callable())
		elif _state.owns(u.id):
			_row(text, "Equip", false, func(): _on_equip_upgrade(u))
		else:
			_row(text, "Craft (%d)" % u.cost, not _state.can_afford(u.cost), func(): _on_craft_upgrade(u))

func _on_craft_upgrade(u: Upgrade) -> void:
	if _state.buy_upgrade(u):
		_admin_label.text = "Admin: %s sudah jadi. Langsung dipasang." % u.display_name
		changed.emit()
	_finish_action()

func _on_equip_upgrade(u: Upgrade) -> void:
	if _state.equip_upgrade(_selected_id, u.id):
		_admin_label.text = "Admin: Berganti ke %s." % u.display_name
		changed.emit()
	_finish_action()

# ---- Equipment ---------------------------------------------------------

func _build_equipment() -> void:
	for e in GearLibrary.equipment():
		var text := "%s   (%s)\n%s" % [e.display_name, e.bonus_text(), e.description]
		if not _state.owns_gear(_selected_id, e.id):
			_row(text, "Craft (%d)" % e.cost, not _state.can_afford(e.cost), func(): _on_craft_gear(e))
		elif _state.is_gear_equipped(_selected_id, e.id):
			_row(text, "Unequip", false, func(): _on_unequip_gear(e))
		elif _state.has_free_slot(_selected_id):
			_row(text, "Equip", false, func(): _on_equip_gear(e))
		else:
			_row(text, "Slots full", true, Callable())

func _on_craft_gear(e: EquipmentItem) -> void:
	var worn_before := _state.is_gear_equipped(_selected_id, e.id)
	if _state.buy_gear(_selected_id, e):
		var worn := _state.is_gear_equipped(_selected_id, e.id) and not worn_before
		_admin_label.text = "Admin: %s selesai dibuat.%s" % [e.display_name, " Langsung dipasang." if worn else " Slot penuh, belum dipasang."]
		changed.emit()
	_finish_action()

func _on_equip_gear(e: EquipmentItem) -> void:
	if _state.equip_gear(_selected_id, e.id):
		_admin_label.text = "Admin: %s dipasang." % e.display_name
		changed.emit()
	_finish_action()

func _on_unequip_gear(e: EquipmentItem) -> void:
	if _state.unequip_gear(_selected_id, e.id):
		_admin_label.text = "Admin: %s dilepas." % e.display_name
		changed.emit()
	_finish_action()

# ---- Skill Knowledge -----------------------------------------------------

func _build_skills(stats: Dictionary) -> void:
	for s in SkillLibrary.for_character(_selected_id):
		var text := "%s   (%s)\n%s\nHitungan: %s" % [s.display_name, s.cost_text, s.summary, s.formula]
		var preview := s.preview_text(stats)
		if preview != "":
			text += "\n" + preview
		if _state.knows_skill(s):
			_row(text, "Learned" if s.unlockable else "Known", true, Callable())
		else:
			_row(text, "Learn (%d)" % s.cost, not _state.can_afford(s.cost), func(): _on_learn_skill(s))

func _on_learn_skill(s: Skill) -> void:
	if _state.learn_skill(s):
		_admin_label.text = "Admin: Skill %s sekarang kamu kuasai." % s.display_name
		changed.emit()
	_finish_action()

func _finish_action() -> void:
	_rebuild()
	focus_first.call_deferred()
