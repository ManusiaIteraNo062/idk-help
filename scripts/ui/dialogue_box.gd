extends Control
class_name DialogueBox
## Story/dialogue box, builds itself in code (same style as BattleUI).
##
## Usage:   await dialogue_box.play(lines)     # lines: Array of DialogueLine
## Controls: click / Space / Enter = advance (first press finishes the
## typewriter, second press goes to the next line). Esc or the Skip button
## closes the whole conversation.
##
## Put this inside a CanvasLayer (layer 10) so it always draws on top.

signal finished

const BOX_HEIGHT := 200.0
const BOX_MARGIN := 40.0
const BOX_BOTTOM_GAP := 24.0
const PORTRAIT_SIZE := 150.0
const CHARS_PER_SECOND := 55.0
const INPUT_GRACE_MS := 150 # ignore input right after opening (stray clicks)

var _lines: Array = []
var _index: int = 0
var _typing: bool = false
var _active: bool = false
var _opened_at: int = 0
var _tween: Tween

var _name_label: Label
var _text_label: RichTextLabel
var _portrait_left: PanelContainer
var _portrait_right: PanelContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP # block clicks to whatever is underneath
	visible = false
	_build_layout()

func _build_layout() -> void:
	var screen := get_viewport_rect().size
	position = Vector2.ZERO
	size = screen

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.position = Vector2.ZERO
	dim.size = screen
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var panel_pos := Vector2(BOX_MARGIN, screen.y - BOX_HEIGHT - BOX_BOTTOM_GAP)
	var panel := PanelContainer.new()
	panel.position = panel_pos
	panel.custom_minimum_size = Vector2(screen.x - BOX_MARGIN * 2.0, BOX_HEIGHT)
	panel.size = panel.custom_minimum_size
	panel.add_theme_stylebox_override("panel", _rect_style(12))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 22)
	col.add_child(_name_label)

	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = false
	_text_label.scroll_active = false
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.add_theme_font_size_override("normal_font_size", 20)
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_text_label)

	var hint := Label.new()
	hint.text = "click / Space: next    Esc: skip"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.modulate = Color(1, 1, 1, 0.5)
	hint.add_theme_font_size_override("font_size", 13)
	col.add_child(hint)

	# Portraits sit fully above the panel's top corners.
	var portrait_y := panel_pos.y - PORTRAIT_SIZE - 8.0
	_portrait_left = _make_portrait(Vector2(BOX_MARGIN + 24.0, portrait_y))
	_portrait_right = _make_portrait(Vector2(screen.x - BOX_MARGIN - 24.0 - PORTRAIT_SIZE, portrait_y))

	var skip := Button.new()
	skip.text = "Skip (Esc)"
	skip.focus_mode = Control.FOCUS_NONE # so Space never "presses" it
	skip.position = Vector2(screen.x - 150.0, 20.0)
	skip.pressed.connect(_close)
	add_child(skip)

## Placeholder portrait: colored rounded box + big initial. If a line has a
## real Texture2D, the TextureRect ("Art") shows it on top of the placeholder.
func _make_portrait(at: Vector2) -> PanelContainer:
	var box := PanelContainer.new()
	box.position = at
	box.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	box.size = box.custom_minimum_size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.visible = false

	var initial := Label.new()
	initial.name = "Initial"
	initial.add_theme_font_size_override("font_size", 72)
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(initial)

	var art := TextureRect.new()
	art.name = "Art"
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.visible = false
	box.add_child(art)

	add_child(box)
	return box

func _apply_portrait(box: PanelContainer, line: DialogueLine) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = line.placeholder_color.darkened(0.35)
	style.set_border_width_all(3)
	style.border_color = Color(1, 1, 1, 0.85)
	style.set_corner_radius_all(14)
	box.add_theme_stylebox_override("panel", style)

	var initial: Label = box.get_node("Initial")
	initial.text = line.speaker.left(1).to_upper()
	var art: TextureRect = box.get_node("Art")
	art.texture = line.portrait
	art.visible = line.portrait != null
	initial.visible = line.portrait == null

## Awaitable. Returns once the player has finished (or skipped) the lines.
func play(lines: Array) -> void:
	if lines.is_empty():
		return
	_lines = lines
	_index = 0
	_active = true
	_opened_at = Time.get_ticks_msec()
	visible = true
	_show_line()
	await finished

func _show_line() -> void:
	var line: DialogueLine = _lines[_index]
	var has_speaker := line.speaker != ""
	var on_left := line.side == DialogueLine.Side.LEFT

	_name_label.text = line.speaker
	_name_label.visible = has_speaker
	_name_label.add_theme_color_override("font_color", line.placeholder_color.lightened(0.35))

	_portrait_left.visible = has_speaker and on_left
	_portrait_right.visible = has_speaker and not on_left
	if has_speaker:
		_apply_portrait(_portrait_left if on_left else _portrait_right, line)

	_text_label.text = line.text
	_text_label.visible_ratio = 0.0
	_typing = true
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_text_label, "visible_ratio", 1.0, maxf(0.2, line.text.length() / CHARS_PER_SECOND))
	_tween.finished.connect(func(): _typing = false)

func _advance() -> void:
	if not _active:
		return
	if Time.get_ticks_msec() - _opened_at < INPUT_GRACE_MS:
		return
	if _typing:
		if _tween:
			_tween.kill()
		_text_label.visible_ratio = 1.0
		_typing = false
		return
	_index += 1
	if _index >= _lines.size():
		_close()
	else:
		_show_line()

func _close() -> void:
	if not _active:
		return
	_active = false
	_typing = false
	visible = false
	if _tween:
		_tween.kill()
	finished.emit()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()
		accept_event()

func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("ui_accept") and not event.is_echo():
		_advance()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()

func _rect_style(corner_radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.92)
	style.set_border_width_all(3)
	style.border_color = Color(1, 1, 1, 0.85)
	style.set_corner_radius_all(corner_radius)
	style.set_content_margin_all(16)
	return style
