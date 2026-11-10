extends Control
class_name EncyclopediaScreen
## Lobby > Enemy Encyclopedia. Same look as the workshop's item list:
## a scrolling list of cards, one per enemy. Name and HP are in a bigger font
## than the move lines. Bosses only show up after you have met them.

signal back_pressed

const NAME_SIZE := 24
const HP_SIZE := 20
const MOVE_SIZE := 16

var _state: GameState
var _list: VBoxContainer
var _scroll: ScrollContainer
var _note: Label
var _back_btn: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var frame := WorkshopStyle.build_frame(820, "ENCYCLOPEDIA")
	center.add_child(frame["root"])
	var col: VBoxContainer = frame["content"]
	col.add_theme_constant_override("separation", 8)

	col.add_child(WorkshopStyle.title_label("MUSUH", 24))

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	col.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_fit_scroll()
	get_viewport().size_changed.connect(_fit_scroll)

	_note = Label.new()
	_note.modulate = Color(1, 1, 1, 0.55)
	_note.add_theme_font_size_override("font_size", 13)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_note)

	_back_btn = Button.new()
	_back_btn.text = "Back to Lobby"
	_back_btn.custom_minimum_size = Vector2(0, 42)
	WorkshopStyle.style_button(_back_btn)
	_back_btn.pressed.connect(func(): back_pressed.emit())
	col.add_child(_back_btn)

func _fit_scroll() -> void:
	var h := get_viewport_rect().size.y
	_scroll.custom_minimum_size = Vector2(0, clampf(h - 280.0, 200.0, 700.0))

func refresh(state: GameState) -> void:
	_state = state
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var shown := EnemyLibrary.visible_for(state)
	for e in shown:
		_list.add_child(_make_card(e))
	var hidden := 0
	for e in EnemyLibrary.all():
		if e.is_boss and not state.has_met(e.enemy_id()):
			hidden += 1
	_note.text = "" if hidden == 0 else "Ada %d musuh lain yang belum kamu temui." % hidden
	_scroll.scroll_vertical = 0

func _make_card(e: EnemyType) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", WorkshopStyle.card_style())
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	col.add_child(head)
	var name_lbl := Label.new()
	name_lbl.text = e.display_name
	name_lbl.add_theme_font_override("font", WorkshopStyle.title_font())
	name_lbl.add_theme_font_size_override("font_size", NAME_SIZE)
	name_lbl.add_theme_color_override("font_color", Color(0.88, 0.7, 0.3) if e.is_boss else WorkshopStyle.TEXT)
	head.add_child(name_lbl)
	if e.is_boss:
		var tag := Label.new()
		tag.text = "BOSS"
		tag.add_theme_font_size_override("font_size", 13)
		tag.add_theme_color_override("font_color", Color(0.9, 0.5, 0.2))
		tag.size_flags_vertical = Control.SIZE_SHRINK_END
		head.add_child(tag)

	var hp := Label.new()
	hp.text = "%d HP" % e.health
	hp.add_theme_font_size_override("font_size", HP_SIZE)
	hp.add_theme_color_override("font_color", WorkshopStyle.TEAL_EDGE)
	col.add_child(hp)

	for m in e.moves:
		var rich := RichTextLabel.new()
		rich.bbcode_enabled = true
		rich.fit_content = true
		rich.scroll_active = false
		rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rich.add_theme_font_size_override("normal_font_size", MOVE_SIZE)
		rich.text = _move_bbcode(m)
		col.add_child(rich)
	return card

## "[color=gold]Slosh[/color] : ..." (the line is escaped so descriptions can't break the markup).
func _move_bbcode(m: Move) -> String:
	var line := EnemyLibrary.move_line(m).replace("[", "[lb]")
	var colon := line.find(" : ")
	if colon < 0:
		return line
	return "[color=#e0b24d]%s[/color]%s" % [line.substr(0, colon), line.substr(colon)]

func focus_first() -> void:
	_back_btn.grab_focus()
