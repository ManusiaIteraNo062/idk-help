extends Control
class_name WorkshopScreen
## Admin's workshop, the entry point from the lobby. Shows two big choices:
##   left  - Equipment   (hammer): upgrades, equipment, skills  -> EquipmentWorkshop
##   right - Preparation (sack):   craft items for missions     -> PreparationWorkshop
## Each sub-screen has its own Back button (and Esc) that returns here.
## Same outside API as before: refresh(state), focus_first(), changed, back_pressed.

signal back_pressed
signal changed

enum View { HUB, EQUIPMENT, PREPARATION }

var _state: GameState
var _view: View = View.HUB

var _hub: Control
var _equipment: EquipmentWorkshop
var _prep: PreparationWorkshop
var _fragments_label: Label
var _equipment_btn: Button
var _prep_btn: Button
var _back_btn: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_hub()

	_equipment = EquipmentWorkshop.new()
	_equipment.changed.connect(func(): changed.emit())
	_equipment.back_pressed.connect(func(): _show(View.HUB))
	add_child(_equipment)

	_prep = PreparationWorkshop.new()
	_prep.changed.connect(func(): changed.emit())
	_prep.back_pressed.connect(func(): _show(View.HUB))
	add_child(_prep)

	_show(View.HUB)

func _build_hub() -> void:
	_hub = Control.new()
	_hub.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_hub)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hub.add_child(center)

	var frame := WorkshopStyle.build_frame(760)
	center.add_child(frame["root"])
	var col: VBoxContainer = frame["content"]
	col.add_theme_constant_override("separation", 14)

	_fragments_label = Label.new()
	_fragments_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_fragments_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)

	_equipment_btn = _make_choice(WorkshopIcon.Kind.HAMMER, "EQUIPMENT", "Upgrade, perlengkapan,\ndan skill karakter")
	_equipment_btn.pressed.connect(func(): _show(View.EQUIPMENT))
	row.add_child(_equipment_btn)
	_prep_btn = _make_choice(WorkshopIcon.Kind.SACK, "PREPARATION", "Item untuk dibawa\nke dalam misi")
	_prep_btn.pressed.connect(func(): _show(View.PREPARATION))
	row.add_child(_prep_btn)

	_back_btn = Button.new()
	_back_btn.text = "Back to Lobby"
	_back_btn.custom_minimum_size = Vector2(0, 44)
	WorkshopStyle.style_button(_back_btn)
	_back_btn.pressed.connect(func(): back_pressed.emit())
	col.add_child(_back_btn)

## One big turquoise choice: icon on top, title, a short Indonesian caption.
func _make_choice(kind: WorkshopIcon.Kind, title: String, caption: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(320, 270)
	WorkshopStyle.style_button(b, 10)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)

	var icon := WorkshopIcon.new()
	icon.kind = kind
	icon.custom_minimum_size = Vector2(110, 110)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)

	var t := WorkshopStyle.title_label(title, 26)
	t.add_theme_color_override("font_color", WorkshopStyle.TEXT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(t)

	var c := Label.new()
	c.text = caption
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_theme_font_size_override("font_size", 14)
	c.add_theme_color_override("font_color", Color(0.86, 0.97, 0.95))
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(c)
	return b

func refresh(state: GameState) -> void:
	_state = state
	_equipment.refresh(state)
	_prep.refresh(state)
	_show(View.HUB)

func focus_first() -> void:
	match _view:
		View.EQUIPMENT:
			_equipment.focus_first()
		View.PREPARATION:
			_prep.focus_first()
		_:
			_equipment_btn.grab_focus()

func _show(view: View) -> void:
	_view = view
	_hub.visible = view == View.HUB
	_equipment.visible = view == View.EQUIPMENT
	_prep.visible = view == View.PREPARATION
	if _state:
		_fragments_label.text = "Shangri-La Fragments: %d" % _state.fragments
		_equipment.refresh(_state)
		_prep.refresh(_state)
	if is_inside_tree() and visible:
		focus_first.call_deferred()

## Esc: back one step (sub-screen -> hub -> lobby).
func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	if _view == View.HUB:
		back_pressed.emit()
	else:
		_show(View.HUB)
	get_viewport().set_input_as_handled()
