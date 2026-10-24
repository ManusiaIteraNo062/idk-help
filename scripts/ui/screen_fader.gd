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
var _card: CenterContainer
var _title: Label
var _subtitle: Label
var _tween: Tween

func _ready() -> void:
	layer = 20
	var screen := get_viewport().get_visible_rect().size

	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 0)
	_rect.position = Vector2.ZERO
	_rect.size = screen
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)

	_card = CenterContainer.new()
	_card.position = Vector2.ZERO
	_card.size = screen
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.visible = false
	add_child(_card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(col)

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
func title_card(title: String, subtitle: String = "", hold: float = 1.6) -> void:
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
