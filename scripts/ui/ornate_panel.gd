extends PanelContainer
class_name OrnatePanel
## The shared "dark panel with gold corner brackets" look from the UI sketches.
## Any container content goes inside as normal children.

@export var accent: Color = Color(0.88, 0.7, 0.3) : set = _set_accent
@export var corner_length: float = 12.0

func _init() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.08, 0.07, 0.94)
	style.set_border_width_all(2)
	style.border_color = Color(0.42, 0.34, 0.17)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)

func _set_accent(c: Color) -> void:
	accent = c
	queue_redraw()

func _draw() -> void:
	var w := 3.0
	var l := corner_length
	var s := size
	var o := 1.0
	# four L-shaped brackets
	draw_line(Vector2(o, o + l), Vector2(o, o), accent, w); draw_line(Vector2(o, o), Vector2(o + l, o), accent, w)
	draw_line(Vector2(s.x - o - l, o), Vector2(s.x - o, o), accent, w); draw_line(Vector2(s.x - o, o), Vector2(s.x - o, o + l), accent, w)
	draw_line(Vector2(o, s.y - o - l), Vector2(o, s.y - o), accent, w); draw_line(Vector2(o, s.y - o), Vector2(o + l, s.y - o), accent, w)
	draw_line(Vector2(s.x - o - l, s.y - o), Vector2(s.x - o, s.y - o), accent, w); draw_line(Vector2(s.x - o, s.y - o - l), Vector2(s.x - o, s.y - o), accent, w)
