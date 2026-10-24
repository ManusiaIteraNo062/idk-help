extends Resource
class_name DialogueLine
## One line of dialogue. The portrait is a colored placeholder box with the
## speaker's first letter until you assign a real `portrait` texture.
## Swapping in art later = set `portrait` on the line; nothing else changes.
## Leave `speaker` empty for narration (no portrait, no name).

enum Side { LEFT, RIGHT }

@export var speaker: String = ""
@export_multiline var text: String = ""
@export_enum("Left", "Right") var side: int = 0 # Side.LEFT / Side.RIGHT
@export var portrait: Texture2D # optional - placeholder is used when null
@export var placeholder_color: Color = Color(0.6, 0.6, 0.6)

static func make(p_speaker: String, p_text: String, p_side: int = 0, p_color: Color = Color(0.6, 0.6, 0.6)) -> DialogueLine:
	var line := DialogueLine.new()
	line.speaker = p_speaker
	line.text = p_text
	line.side = p_side
	line.placeholder_color = p_color
	return line
