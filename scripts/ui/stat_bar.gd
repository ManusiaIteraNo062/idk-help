extends Control
class_name StatBar
## A flat bar for HP (smooth) or Energy (segmented). Draws itself, so there are
## no textures to import; swap _draw() for art later. `value` animates.

@export var max_value: float = 100.0
@export var fill_color: Color = Color(0.85, 0.2, 0.2)
@export var back_color: Color = Color(0.05, 0.05, 0.05, 0.9)
@export var frame_color: Color = Color(0.55, 0.45, 0.2)
## 0 = smooth bar. N > 0 = N equal segments (Energy: 5).
@export var segments: int = 0

var value: float = 0.0 : set = _set_value
var _tween: Tween

func _init() -> void:
	custom_minimum_size = Vector2(60, 12)

func set_target(new_value: float, new_max: float = -1.0, animate: bool = true) -> void:
	if new_max >= 0.0:
		max_value = maxf(1.0, new_max)
	if _tween:
		_tween.kill()
	if animate and is_inside_tree():
		_tween = create_tween()
		_tween.tween_property(self, "value", new_value, 0.25)
	else:
		value = new_value

func _set_value(v: float) -> void:
	value = v
	queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, back_color)
	var ratio := clampf(value / maxf(1.0, max_value), 0.0, 1.0)
	if segments > 0:
		var gap := 2.0
		var seg_w := (size.x - gap * (segments - 1)) / segments
		var filled := value / maxf(1.0, max_value) * segments
		for i in segments:
			var seg := Rect2(i * (seg_w + gap), 0, seg_w, size.y)
			if i + 1 <= filled + 0.001:
				draw_rect(seg, fill_color)
			else:
				draw_rect(seg, Color(1, 1, 1, 0.06))
	else:
		draw_rect(Rect2(0, 0, size.x * ratio, size.y), fill_color)
	draw_rect(r, frame_color, false, 1.5)
