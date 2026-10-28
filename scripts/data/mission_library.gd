extends RefCounted
class_name MissionLibrary
## Loads every mission from res://data/missions/. One folder per mission:
##
##   data/missions/01_permulaan_baru/
##     mission.tres    title, location, reward, waves of enemies
##     intro.txt       dialogue before the battle
##     victory.txt     dialogue after a win
##     defeat.txt      dialogue after a loss
##
## Folder names are sorted alphabetically = board order, so number them
## (01_, 02_, ... 10_). Adding a mission = adding a folder. No code changes.
## Dialogue format: see DialogueParser. Lobby text: data/lobby/intro.txt.
##
## EXPORT NOTE: add "*.txt" to Project > Export > Resources > "Filters to
## export non-resource files" or the dialogue files won't ship in the build.

const MISSIONS_DIR := "res://data/missions"
const LOBBY_INTRO := "res://data/lobby/intro.txt"

static func build_all() -> Array[Mission]:
	var out: Array[Mission] = []
	var dirs := DirAccess.get_directories_at(MISSIONS_DIR)
	dirs.sort()
	for d in dirs:
		var m := _load_mission("%s/%s" % [MISSIONS_DIR, d])
		if m:
			out.append(m)
	if out.is_empty():
		push_error("No missions found in %s" % MISSIONS_DIR)
	return out

static func _load_mission(dir: String) -> Mission:
	var path := dir + "/mission.tres"
	if not ResourceLoader.exists(path):
		push_warning("Skipping %s (no mission.tres)" % dir)
		return null
	var m := load(path) as Mission
	if m == null:
		push_error("%s is not a Mission resource" % path)
		return null
	m.intro_lines = DialogueParser.load_file(dir + "/intro.txt")
	m.victory_lines = DialogueParser.load_file(dir + "/victory.txt")
	m.defeat_lines = DialogueParser.load_file(dir + "/defeat.txt")
	return m

## Lobby dialogue played on entering the lobby (first visit only for now).
static func lobby_visit_lines(state: GameState) -> Array[DialogueLine]:
	if not state.seen_lobby_intro:
		return DialogueParser.load_file(LOBBY_INTRO)
	return [] as Array[DialogueLine]
