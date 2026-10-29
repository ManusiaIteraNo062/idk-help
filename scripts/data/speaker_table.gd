extends RefCounted
class_name SpeakerTable
## Who is who in dialogue files: portrait color + default side.
## A new character (or boss) = one new entry here, then just write
## "Name: line" in the .txt files. Unknown names still work (grey, right side).

## "Admin (via Drone)" uses Admin's entry; the full text is still what is displayed.
static func lookup(speaker: String) -> Dictionary:
	var paren := speaker.find(" (")
	if paren > 0:
		speaker = speaker.substr(0, paren)
	var L := DialogueLine.Side.LEFT
	var R := DialogueLine.Side.RIGHT
	var table := {
		"Helder": {"color": Roster.HELDER_COLOR, "side": L},
		"Radik": {"color": Roster.RADIK_COLOR, "side": R},
		"Dean": {"color": Roster.DEAN_COLOR, "side": R},
		"Admin": {"color": Roster.ADMIN_COLOR, "side": R},
		"WYG-01": {"color": Roster.ADMIN_COLOR, "side": R},
	}
	return table.get(speaker, {"color": Color(0.6, 0.6, 0.6), "side": R})
