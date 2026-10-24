extends Control
class_name LobbyScreen
## The hub between missions: go to the mission board, spend fragments at
## Admin's workshop, or (once unlocked) enter Training.
## Builds itself in code. Keyboard: arrows move, Space/Enter confirms.

signal missions_pressed
signal workshop_pressed
signal training_pressed

var _fragments_label: Label
var _missions_btn: Button
var _workshop_btn: Button
var _training_btn: Button

func _ready() -> void:
	var screen := get_viewport_rect().size
	position = Vector2.ZERO
	size = screen

	var center := CenterContainer.new()
	center.size = screen
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	panel.add_theme_stylebox_override("panel", _rect_style(12))
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	var title := Label.new()
	title.text = "KULON CONCIERGE & JOINERY INC."
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var sub := Label.new()
	sub.text = "Lobby"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(1, 1, 1, 0.6)
	col.add_child(sub)

	_fragments_label = Label.new()
	_fragments_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_fragments_label)

	_missions_btn = _make_button(col, "Take a Mission", func(): missions_pressed.emit())
	_workshop_btn = _make_button(col, "Admin's Workshop", func(): workshop_pressed.emit())
	_training_btn = _make_button(col, "Training", func(): training_pressed.emit())

func _make_button(parent: Node, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 56)
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func refresh(state: GameState) -> void:
	_fragments_label.text = "Shangri-La Fragments: %d" % state.fragments
	var unlocked := state.training_unlocked()
	_training_btn.disabled = not unlocked
	_training_btn.text = "Training" if unlocked else "Training  (unlocks after Suara Merdu)"

func focus_first() -> void:
	_missions_btn.grab_focus()

func _rect_style(corner_radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	style.set_border_width_all(3)
	style.border_color = Color(1, 1, 1, 0.85)
	style.set_corner_radius_all(corner_radius)
	style.set_content_margin_all(24)
	return style
