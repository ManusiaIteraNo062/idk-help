extends Control
class_name TitleScreen
## The first screen: Continue / New Game / Quit.
##   Continue  - needs a save; goes to the lobby with your progress.
##   New Game  - asks first if a save exists (it is deleted), then the first
##               mission starts straight away (see GameFlow).
## Look matches the workshop: silver frame, turquoise choices, Cinzel titles.

signal continue_pressed
signal new_game_pressed   # already confirmed
signal quit_pressed

## Set by GameFlow so the summary can say "5 / 13 missions".
var total_missions: int = 0

var _continue_btn: Button
var _new_btn: Button
var _quit_btn: Button
var _summary: Label
var _confirm: Control
var _confirm_no: Button
var _has_save: bool = false
var _save_path: String = GameState.SAVE_PATH

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.07)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	center.add_child(col)

	var title := WorkshopStyle.title_label("HADIRION", 72)
	title.add_theme_color_override("font_color", WorkshopStyle.SILVER)
	col.add_child(title)
	var sub := WorkshopStyle.title_label("KULON OFFICE CHRONICLES", 22)
	sub.add_theme_color_override("font_color", WorkshopStyle.TEAL_EDGE)
	col.add_child(sub)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 26)
	col.add_child(gap)

	_continue_btn = _make_button(col, "Continue")
	_continue_btn.pressed.connect(func(): continue_pressed.emit())
	_summary = Label.new()
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary.add_theme_font_size_override("font_size", 14)
	_summary.modulate = Color(1, 1, 1, 0.7)
	col.add_child(_summary)
	_new_btn = _make_button(col, "New Game")
	_new_btn.pressed.connect(_on_new_pressed)
	_quit_btn = _make_button(col, "Quit")
	_quit_btn.pressed.connect(func(): quit_pressed.emit())

	_build_confirm()

func _make_button(parent: Node, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 52)
	b.add_theme_font_size_override("font_size", 20)
	WorkshopStyle.style_button(b, 8)
	parent.add_child(b)
	return b

## "Delete your progress?" box shown over the title when a save exists.
func _build_confirm() -> void:
	_confirm = Control.new()
	_confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.visible = false
	add_child(_confirm)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	panel.add_theme_stylebox_override("panel", WorkshopStyle.frame_style())
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	col.add_child(WorkshopStyle.title_label("GAME BARU?", 24))
	var msg := Label.new()
	msg.text = "Progres yang tersimpan (Fragments, upgrade, equipment, skill, dan item) akan dihapus dan tidak bisa dikembalikan."
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(msg)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	_confirm_no = Button.new()
	_confirm_no.text = "Batal"
	_confirm_no.custom_minimum_size = Vector2(190, 46)
	WorkshopStyle.style_button(_confirm_no)
	_confirm_no.pressed.connect(_close_confirm)
	row.add_child(_confirm_no)
	var yes := Button.new()
	yes.text = "Ya, mulai baru"
	yes.custom_minimum_size = Vector2(190, 46)
	WorkshopStyle.style_button(yes)
	yes.pressed.connect(func():
		_close_confirm()
		new_game_pressed.emit()
	)
	row.add_child(yes)

func refresh(state: GameState) -> void:
	_save_path = state.save_path
	_has_save = FileAccess.file_exists(_save_path)
	_continue_btn.disabled = not _has_save
	if _has_save:
		var total := "" if total_missions <= 0 else " / %d" % total_missions
		_summary.text = "Fragments: %d     Misi selesai: %d%s" % [state.fragments, state.cleared.size(), total]
	else:
		_summary.text = "Belum ada data tersimpan"
	_close_confirm()

func focus_first() -> void:
	if _has_save:
		_continue_btn.grab_focus()
	else:
		_new_btn.grab_focus()

func _on_new_pressed() -> void:
	if not _has_save:
		new_game_pressed.emit() # nothing to lose, no question needed
		return
	_confirm.visible = true
	_confirm_no.grab_focus() # the safe choice is highlighted first

func _close_confirm() -> void:
	if _confirm.visible:
		_confirm.visible = false
		_new_btn.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if visible and _confirm.visible and event.is_action_pressed("ui_cancel"):
		_close_confirm()
		get_viewport().set_input_as_handled()
