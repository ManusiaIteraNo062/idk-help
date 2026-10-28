extends RefCounted
class_name DialogueParser
## Turns a plain-text dialogue file into DialogueLine resources.
##
##   # comment (ignored), blank lines are ignored too
##   Dean: You're the new hire.            <- speaker line (side/color from SpeakerTable)
##   Helder [R]: Override the side.        <- optional [L] or [R]
##   > Narration has no speaker.            <- narration starts with ">"

## Longer lines are split at sentence ends into several consecutive lines
## (same speaker) so they fit the dialogue box. Raise it if you make the box bigger.
const MAX_CHARS := 230

static func parse(text: String) -> Array[DialogueLine]:
	var out: Array[DialogueLine] = []
	text = text.trim_prefix("\uFEFF") # Notepad's invisible UTF-8 marker
	var n := 0
	for raw in text.split("\n"):
		n += 1
		var line := raw.strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		if line.begins_with(">"):
			for piece in _split_long(line.substr(1).strip_edges()):
				out.append(DialogueLine.make("", piece))
			continue

		var colon := line.find(":")
		if colon <= 0:
			push_warning("Dialogue line %d has no 'Name:' - shown as narration: %s" % [n, line])
			out.append(DialogueLine.make("", line))
			continue

		var head := line.substr(0, colon).strip_edges()
		var body := line.substr(colon + 1).strip_edges()
		var side_override := -1
		if head.ends_with("]") and head.contains("["):
			var open := head.rfind("[")
			var tag := head.substr(open + 1, head.length() - open - 2).strip_edges().to_upper()
			if tag == "L":
				side_override = DialogueLine.Side.LEFT
			elif tag == "R":
				side_override = DialogueLine.Side.RIGHT
			else:
				push_warning("Dialogue line %d: unknown side tag [%s] (use L or R)" % [n, tag])
			head = head.substr(0, open).strip_edges()

		var info := SpeakerTable.lookup(head)
		var side: int = side_override if side_override != -1 else info["side"]
		for piece in _split_long(body):
			out.append(DialogueLine.make(head, piece, side, info["color"]))
	return out

## Greedy split after ". " / "! " / "? " / "... " boundaries, never mid-sentence.
static func _split_long(text: String) -> PackedStringArray:
	if text.length() <= MAX_CHARS:
		return PackedStringArray([text])
	var re := RegEx.new()
	re.compile("(?<=[.!?\u2026])\\s+")
	var sentences: PackedStringArray = []
	var last := 0
	for m in re.search_all(text):
		sentences.append(text.substr(last, m.get_start() - last))
		last = m.get_end()
	sentences.append(text.substr(last))
	var out: PackedStringArray = []
	var cur := ""
	for s in sentences:
		if cur != "" and cur.length() + 1 + s.length() > MAX_CHARS:
			out.append(cur)
			cur = s
		else:
			cur = s if cur == "" else cur + " " + s
	if cur != "":
		out.append(cur)
	return out

static func load_file(path: String) -> Array[DialogueLine]:
	if not FileAccess.file_exists(path):
		return [] as Array[DialogueLine]
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Could not open dialogue file: %s" % path)
		return [] as Array[DialogueLine]
	return parse(f.get_as_text())
