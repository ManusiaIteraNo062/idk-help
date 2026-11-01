extends Control
class_name WorkshopIcon
## Hand-drawn (code) hammer and sack icons for the workshop's two choices.
## Replace _draw() with a TextureRect later if you get real icon art.

enum Kind { HAMMER, SACK }

@export var kind: Kind = Kind.HAMMER
@export var color: Color = Color(0.82, 0.96, 0.94)
@export var outline: Color = Color(0.02, 0.15, 0.17)

func _init() -> void:
	custom_minimum_size = Vector2(96, 96)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	draw_set_transform(size * 0.5, 0.0, Vector2.ONE)
	if kind == Kind.HAMMER:
		_draw_hammer()
	else:
		_draw_sack()

func _poly(points: Array, fill: Color) -> void:
	var pts := PackedVector2Array(points)
	draw_colored_polygon(pts, fill)
	var closed := PackedVector2Array(points)
	closed.append(points[0])
	draw_polyline(closed, outline, 2.5)

func _rot(p: Vector2, deg: float) -> Vector2:
	return p.rotated(deg_to_rad(deg))

func _draw_hammer() -> void:
	var a := 40.0 # tilt, degrees
	# handle
	var h: Array = []
	for p in [Vector2(-6, -4), Vector2(6, -4), Vector2(6, 42), Vector2(-6, 42)]:
		h.append(_rot(p, a))
	_poly(h, color.darkened(0.25))
	# head
	var head: Array = []
	for p in [Vector2(-30, -30), Vector2(30, -30), Vector2(30, -8), Vector2(-30, -8)]:
		head.append(_rot(p, a))
	_poly(head, color)
	# face highlight
	var f1 := _rot(Vector2(-22, -21), a)
	var f2 := _rot(Vector2(22, -21), a)
	draw_line(f1, f2, Color(1, 1, 1, 0.55), 3.0)

func _draw_sack() -> void:
	# body
	var body: Array = []
	for i in 28:
		var t := float(i) / 28.0 * TAU
		body.append(Vector2(cos(t) * 32.0, 14.0 + sin(t) * 30.0))
	_poly(body, color.darkened(0.15))
	# neck
	_poly([Vector2(-11, -12), Vector2(11, -12), Vector2(16, -22), Vector2(-16, -22)], color.darkened(0.15))
	# flared top
	_poly([Vector2(-20, -34), Vector2(-9, -22), Vector2(-3, -34), Vector2(3, -34), Vector2(9, -22), Vector2(20, -34), Vector2(14, -22), Vector2(-14, -22)], color)
	# tie
	draw_line(Vector2(-13, -12), Vector2(13, -12), outline, 4.0)
	draw_line(Vector2(-13, -12), Vector2(13, -12), Color(0.38, 0.86, 0.82), 2.0)
	# stitch highlight
	draw_arc(Vector2(-6, 18), 20.0, deg_to_rad(120), deg_to_rad(200), 10, Color(1, 1, 1, 0.45), 3.0)
