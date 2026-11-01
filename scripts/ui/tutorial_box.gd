extends Control
class_name TutorialBox
## A paged "how to play" box shown over the battle (see TutorialPage for the
## text format). Look: dark framed panel, title top-left in cyan, device badges
## above, centered Indonesian text below.
##
##   await tutorial.play(pages)   # returns when the player closes it
##
## Space / Enter / click: next page.  Left / Right: change page.  Esc: skip.

signal finished

const DEVICE_COLORS := {
	"Attack": Color(0.72, 0.18, 0.16),
	"Alteration": Color(0.5, 0.28, 0.72),
	"Item": Color(0.3, 0.62, 0.26),
	"Guard": Color(0.18, 0.56, 0.76),
}

var _pages: Array[TutorialPage] = []
var _index: int = 0
var _title: Label
var _counter: Label
var _body: VBoxContainer
var _back_btn: Button
var _next_btn: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := OrnatePanel.new()
	panel.custom_minimum_size = Vector2(780, 0)
	panel.corner_length = 18.0
	var margin := panel.get_theme_stylebox("panel") as StyleBoxFlat
	margin.content_margin_left = 30
	margin.content_margin_right = 30
	margin.content_margin_top = 22
	margin.content_margin_bottom = 20
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	_title = Label.new()
	_title.add_theme_font_override("font", WorkshopStyle.title_font())
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", Color(0.4, 0.92, 0.9))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_counter = Label.new()
	_counter.modulate = Color(1, 1, 1, 0.6)
	head.add_child(_counter)

	var line := ColorRect.new()
	line.color = Color(0.88, 0.7, 0.3, 0.5)
	line.custom_minimum_size = Vector2(0, 2)
	col.add_child(line)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	_body.custom_minimum_size = Vector2(0, 250)
	col.add_child(_body)

	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	foot.add_theme_constant_override("separation", 10)
	col.add_child(foot)
	var hint := Label.new()
	hint.text = "Space / Enter: lanjut     Esc: lewati"
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(1, 1, 1, 0.5)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	foot.add_child(hint)
	_back_btn = Button.new()
	_back_btn.text = "Kembali"
	_back_btn.custom_minimum_size = Vector2(130, 40)
	WorkshopStyle.style_button(_back_btn)
	_back_btn.pressed.connect(func(): _go(-1))
	foot.add_child(_back_btn)
	_next_btn = Button.new()
	_next_btn.custom_minimum_size = Vector2(130, 40)
	WorkshopStyle.style_button(_next_btn)
	_next_btn.pressed.connect(func(): _go(1))
	foot.add_child(_next_btn)

## Shows the pages and waits until the player finishes or skips.
func play(pages: Array[TutorialPage]) -> void:
	if pages.is_empty():
		return
	_pages = pages
	_index = 0
	visible = true
	_show_page()
	await finished
	visible = false

func _go(step: int) -> void:
	var target := _index + step
	if target >= _pages.size():
		finished.emit()
		return
	_index = clampi(target, 0, _pages.size() - 1)
	_show_page()

func _show_page() -> void:
	var p := _pages[_index]
	_title.text = p.title
	_counter.text = "%d / %d" % [_index + 1, _pages.size()]
	_back_btn.visible = _index > 0
	_next_btn.text = "Mulai" if _index == _pages.size() - 1 else "Lanjut"
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	for r in p.rows:
		_body.add_child(_make_row(r[0], r[1]))
	for t in p.paragraphs:
		var l := Label.new()
		l.text = t
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 17)
		_body.add_child(l)
	_next_btn.grab_focus()

## A colored device badge (button / key, in English) with its explanation beside it.
func _make_row(device: String, text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var badge := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = DEVICE_COLORS.get(device, WorkshopStyle.TEAL_DARK)
	st.border_color = Color(0.88, 0.7, 0.3) if DEVICE_COLORS.has(device) else WorkshopStyle.TEAL_EDGE
	st.set_border_width_all(2)
	st.set_corner_radius_all(4)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 3
	st.content_margin_bottom = 3
	badge.add_theme_stylebox_override("panel", st)
	badge.custom_minimum_size = Vector2(230, 0)
	var dl := Label.new()
	dl.text = device
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dl.add_theme_font_size_override("font_size", 16)
	badge.add_child(dl)
	row.add_child(badge)
	var tl := Label.new()
	tl.text = text
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tl.add_theme_font_size_override("font_size", 15)
	row.add_child(tl)
	return row

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		finished.emit()
	elif event.is_action_pressed("ui_right"):
		_go(1)
	elif event.is_action_pressed("ui_left") and _index > 0:
		_go(-1)
	else:
		return
	get_viewport().set_input_as_handled()
