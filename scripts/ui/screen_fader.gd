extends CanvasLayer
class_name ScreenFader
## Black fade overlay + title card, drawn above everything (layer 20).
## Used for every transition: menu <-> menu, menu -> cutscene,
## cutscene -> battle, battle -> cutscene.
##
##   await fader.fade_out()                 # screen goes black
##   await fader.title_card("Title", "sub") # shown while black
##   await fader.fade_in()                  # reveal
##
## While the screen is (becoming) black, mouse input is blocked.

var _rect: ColorRect
var _card: Control            # the whole title card (background + text), faded as one
var _card_bg: TextureRect     # picture behind the card text
var _placeholder_bg: GradientTexture2D
var _title: Label
var _subtitle: Label
var _tween: Tween

func _ready() -> void:
	layer = 20
	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 0)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)

	_card = Control.new()
	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.visible = false
	add_child(_card)

	# Placeholder background (a soft dark-teal glow). A mission can supply its own picture.
	_placeholder_bg = GradientTexture2D.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.09, 0.2, 0.24))
	grad.set_color(1, Color(0.01, 0.02, 0.03))
	_placeholder_bg.gradient = grad
	_placeholder_bg.fill = GradientTexture2D.FILL_RADIAL
	_placeholder_bg.fill_from = Vector2(0.5, 0.5)
	_placeholder_bg.fill_to = Vector2(1.0, 0.9)
	_placeholder_bg.width = 256
	_placeholder_bg.height = 256
	_card_bg = TextureRect.new()
	_card_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_card_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_card_bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(col)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 44)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)

	_subtitle = Label.new()
	_subtitle.add_theme_font_size_override("font_size", 20)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.modulate = Color(1, 1, 1, 0.75)
	col.add_child(_subtitle)

func fade_out(duration: float = 0.4) -> void:
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	await _fade_to(1.0, duration)

func fade_in(duration: float = 0.4) -> void:
	await _fade_to(0.0, duration)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _fade_to(alpha: float, duration: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_rect, "color:a", alpha, duration)
	await _tween.finished

## Call while the screen is black. Fades the text in, holds, fades it out.
func title_card(title: String, subtitle: String = "", hold: float = 1.6, background: Texture2D = null) -> void:
	_card_bg.texture = background if background != null else _placeholder_bg
	_title.text = title
	_subtitle.text = subtitle
	_subtitle.visible = subtitle != ""
	_card.modulate.a = 0.0
	_card.visible = true
	var t := create_tween()
	t.tween_property(_card, "modulate:a", 1.0, 0.4)
	t.tween_interval(hold)
	t.tween_property(_card, "modulate:a", 0.0, 0.4)
	await t.finished
	_card.visible = false
