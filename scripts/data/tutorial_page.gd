extends RefCounted
class_name TutorialPage
## One page of a mission's tutorial (data/missions/NN_name/tutorial.txt).
##
##   - Pages are separated by a line with only  ---
##   - The first line of a page is its title.
##   - "> Device | explanation" makes a row: the device (button / key name,
##     keep it in English) on a colored badge, the explanation (Indonesian) next to it.
##   - Any other line is a paragraph.
##   - Lines starting with # are comments.

var title: String = ""
var rows: Array = []                       # [ [device, explanation], ... ]
var paragraphs: PackedStringArray = []

static func parse(text: String) -> Array[TutorialPage]:
	var pages: Array[TutorialPage] = []
	text = text.trim_prefix("\uFEFF")
	var current := TutorialPage.new()
	var has_content := false
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("#"):
			continue
		if line == "---":
			if has_content:
				pages.append(current)
			current = TutorialPage.new()
			has_content = false
			continue
		if line == "":
			continue
		has_content = true
		if current.title == "":
			current.title = line
		elif line.begins_with(">"):
			var body := line.substr(1).strip_edges()
			var bar := body.find("|")
			if bar > 0:
				current.rows.append([body.substr(0, bar).strip_edges(), body.substr(bar + 1).strip_edges()])
			else:
				current.paragraphs.append(body)
		else:
			current.paragraphs.append(line)
	if has_content:
		pages.append(current)
	return pages

static func load_file(path: String) -> Array[TutorialPage]:
	if not FileAccess.file_exists(path):
		return [] as Array[TutorialPage]
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return [] as Array[TutorialPage]
	return parse(f.get_as_text())
