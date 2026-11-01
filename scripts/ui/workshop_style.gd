extends RefCounted
class_name WorkshopStyle
## Shared look for every workshop screen: silver-white frame, dark inside
## (same as before), a "WORKSHOP" sign tab on top, turquoise choices.
## Fonts: Cinzel for titles/signs, Lora (the project default) for body text.

const SILVER := Color(0.88, 0.9, 0.93)
const SILVER_DIM := Color(0.6, 0.62, 0.66)
const PANEL_BG := Color(0.1, 0.1, 0.1, 0.92)

# Turquoise palette (dark -> light). Text on every one of these is near-white.
const TEAL_DEEP := Color(0.02, 0.17, 0.19)
const TEAL_DARK := Color(0.04, 0.26, 0.28)
const TEAL := Color(0.07, 0.40, 0.42)
const TEAL_LIGHT := Color(0.13, 0.58, 0.58)
const TEAL_EDGE := Color(0.38, 0.86, 0.82)
const TEXT := Color(0.92, 1.0, 0.98)
const TEXT_DIM := Color(0.62, 0.78, 0.77)

static var _title_font: FontVariation

static func title_font() -> Font:
	if _title_font == null:
		_title_font = FontVariation.new()
		_title_font.base_font = load("res://assets/fonts/Cinzel.ttf")
		_title_font.variation_embolden = 0.35
	return _title_font

static func title_label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", title_font())
	l.add_theme_font_size_override("font_size", size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

static func frame_style() -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = PANEL_BG
	st.set_border_width_all(4)
	st.border_color = SILVER
	st.set_corner_radius_all(12)
	st.content_margin_left = 22
	st.content_margin_right = 22
	st.content_margin_top = 22
	st.content_margin_bottom = 18
	return st

## Returns { "root": Control to add to your screen, "content": VBoxContainer to fill }.
## A rounded "WORKSHOP" sign tab sits on the top edge of the silver frame.
static func build_frame(width: float) -> Dictionary:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 0)

	var sign_row := HBoxContainer.new()
	sign_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(sign_row)
	var sign := PanelContainer.new()
	var ss := StyleBoxFlat.new()
	ss.bg_color = PANEL_BG
	ss.border_width_left = 4
	ss.border_width_right = 4
	ss.border_width_top = 4
	ss.border_color = SILVER
	ss.corner_radius_top_left = 26
	ss.corner_radius_top_right = 26
	ss.content_margin_left = 34
	ss.content_margin_right = 34
	ss.content_margin_top = 6
	ss.content_margin_bottom = 4
	sign.add_theme_stylebox_override("panel", ss)
	sign.add_child(title_label("WORKSHOP", 22))
	sign_row.add_child(sign)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	panel.add_theme_stylebox_override("panel", frame_style())
	root.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	return {"root": root, "content": content}

static func _flat(bg: Color, border: Color, border_w: int, radius: int = 6) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.set_border_width_all(border_w)
	st.set_corner_radius_all(radius)
	st.content_margin_left = 14
	st.content_margin_right = 14
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	return st

## Turquoise button look (tabs, Craft/Equip, big choices). Toggle buttons look
## "selected" when pressed.
static func style_button(b: Button, radius: int = 6) -> void:
	b.add_theme_stylebox_override("normal", _flat(TEAL_DARK, TEAL, 1, radius))
	b.add_theme_stylebox_override("hover", _flat(TEAL, TEAL_EDGE, 2, radius))
	b.add_theme_stylebox_override("pressed", _flat(TEAL, SILVER, 2, radius))
	b.add_theme_stylebox_override("hover_pressed", _flat(TEAL_LIGHT, SILVER, 2, radius))
	b.add_theme_stylebox_override("focus", _flat(TEAL_LIGHT, SILVER, 3, radius))
	b.add_theme_stylebox_override("disabled", _flat(Color(0.07, 0.12, 0.13), Color(0.18, 0.28, 0.29), 1, radius))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, TEXT)
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.68, 0.68, 0.7))

## A quiet card behind an info row.
static func card_style() -> StyleBoxFlat:
	var st := _flat(Color(0.13, 0.14, 0.15), Color(0.28, 0.3, 0.32), 1, 6)
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	return st
