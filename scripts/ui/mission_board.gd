extends Control
class_name MissionBoard
## The mission select screen. A mission unlocks once the one before it has
## been cleared. Cleared missions can be replayed (at a reduced reward).
## Builds itself in code; call refresh(state) whenever it is shown.

signal mission_selected(mission: Mission)
signal back_pressed

var missions: Array[Mission] = []

var _list: VBoxContainer
var _footer: Label
var _back_btn: Button
var _next_btn: Button # the first unlocked, not-yet-cleared mission

func _ready() -> void:
	var screen := get_viewport_rect().size
	position = Vector2.ZERO
	size = screen

	var center := CenterContainer.new()
	center.size = screen
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(800, 0)
	panel.add_theme_stylebox_override("panel", _rect_style(12))
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)

	var title := Label.new()
	title.text = "MISSION BOARD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	col.add_child(title)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	col.add_child(_list)

	_footer = Label.new()
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.modulate = Color(1, 1, 1, 0.7)
	col.add_child(_footer)

	_back_btn = Button.new()
	_back_btn.text = "Back to Lobby"
	_back_btn.custom_minimum_size = Vector2(0, 48)
	_back_btn.pressed.connect(func(): back_pressed.emit())
	col.add_child(_back_btn)

func refresh(state: GameState) -> void:
	_next_btn = null
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()

	for i in range(missions.size()):
		var m: Mission = missions[i]
		var is_cleared := state.is_cleared(m.id)
		var unlocked: bool = i == 0 or state.is_cleared(missions[i - 1].id)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 100)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.disabled = not unlocked
		if unlocked:
			var place := "  |  %s" % m.location if m.location != "" else ""
			btn.text = "%d. %s   [%s]%s\n%s\nReward: %d fragments%s" % [
				i + 1, m.title, m.difficulty, "   (cleared)" if is_cleared else "",
				m.summary, m.fragment_reward, place
			]
			btn.pressed.connect(func(): mission_selected.emit(m))
			if not is_cleared and _next_btn == null:
				_next_btn = btn
		else:
			btn.text = "%d. ???   [Locked]\nClear the previous mission to unlock." % (i + 1)
		_list.add_child(btn)

	var all_cleared := not missions.is_empty() and state.is_cleared(missions[missions.size() - 1].id)
	_footer.text = "All missions cleared - more coming soon." if all_cleared else ""

func focus_first() -> void:
	if _next_btn and is_instance_valid(_next_btn):
		_next_btn.grab_focus()
		return
	for c in _list.get_children():
		if c is Button and not c.disabled:
			c.grab_focus()
			return
	_back_btn.grab_focus()

func _rect_style(corner_radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	style.set_border_width_all(3)
	style.border_color = Color(1, 1, 1, 0.85)
	style.set_corner_radius_all(corner_radius)
	style.set_content_margin_all(20)
	return style
