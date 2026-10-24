extends Control
class_name RewardPopup
## "Mission complete" panel showing the Shangri-La Fragments earned.
## Usage: await reward_popup.show_rewards(title, amount, first_clear, total)
## Put it inside the same CanvasLayer as the DialogueBox.

signal _continued

var _mission_lbl: Label
var _amount_lbl: Label
var _note_lbl: Label
var _total_lbl: Label
var _btn: Button

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var screen := get_viewport_rect().size
	position = Vector2.ZERO
	size = screen

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.size = screen
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.size = screen
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	panel.add_theme_stylebox_override("panel", _rect_style(12))
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var title := Label.new()
	title.text = "MISSION COMPLETE"
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	_mission_lbl = _centered_label(col, 18)
	_amount_lbl = _centered_label(col, 26)
	_note_lbl = _centered_label(col, 16)
	_note_lbl.modulate = Color(1, 1, 1, 0.7)
	_total_lbl = _centered_label(col, 16)

	_btn = Button.new()
	_btn.text = "Continue"
	_btn.custom_minimum_size = Vector2(0, 48)
	_btn.pressed.connect(func(): _continued.emit())
	col.add_child(_btn)

func _centered_label(parent: Node, font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l

func show_rewards(mission_title: String, amount: int, first_clear: bool, total: int) -> void:
	_mission_lbl.text = mission_title
	_amount_lbl.text = "+%d Shangri-La Fragments" % amount
	_note_lbl.text = "First clear!" if first_clear else "Replay reward (reduced)"
	_total_lbl.text = "Total: %d" % total
	visible = true
	# Short grace period so the key press that closed the dialogue can't
	# instantly dismiss this popup too.
	_btn.disabled = true
	await get_tree().create_timer(0.4).timeout
	_btn.disabled = false
	_btn.grab_focus()
	await _continued
	visible = false

func _rect_style(corner_radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	style.set_border_width_all(3)
	style.border_color = Color(1, 1, 1, 0.85)
	style.set_corner_radius_all(corner_radius)
	style.set_content_margin_all(24)
	return style
