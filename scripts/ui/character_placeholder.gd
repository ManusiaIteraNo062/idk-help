extends Node2D
class_name CharacterPlaceholder
## Draws a simple stick figure with code - no sprite/art needed yet.
## Swap _draw() for a Sprite2D/AnimatedSprite2D later; nothing that
## positions or references this node has to change.

@export var color: Color = Color.WHITE
@export var figure_scale: float = 1.0

func _draw() -> void:
	var s := figure_scale
	var line_width := 4.0 * s

	# Head
	draw_circle(Vector2(0, -60 * s), 12 * s, color)
	# Torso
	draw_line(Vector2(0, -48 * s), Vector2(0, 10 * s), color, line_width)
	# Arms
	draw_line(Vector2(0, -30 * s), Vector2(-22 * s, -10 * s), color, line_width)
	draw_line(Vector2(0, -30 * s), Vector2(22 * s, -10 * s), color, line_width)
	# Legs
	draw_line(Vector2(0, 10 * s), Vector2(-16 * s, 50 * s), color, line_width)
	draw_line(Vector2(0, 10 * s), Vector2(16 * s, 50 * s), color, line_width)

func set_color(new_color: Color) -> void:
	color = new_color
	queue_redraw()
