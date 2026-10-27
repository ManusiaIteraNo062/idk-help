extends RefCounted
class_name MissionLibrary
## Builds the three story missions from the GDD:
##   1) Permulaan Baru - Level 1-Prologue, Tarakan, Lampung (tutorial)
##   2) Kulon Office   - Level 1-1, Cilegon, Banten
##   3) Suara Merdu    - boss; clearing it unlocks Training
##
## ALL story text below is PLACEHOLDER (English, easy to translate - every
## line lives in this file). Enemy numbers are first-pass tuning knobs.
## NOTE: the GDD wants 2 / 3 / 1 enemy waves per level; each mission here is
## still a single wave (waves are being added on the combat side).

const L := DialogueLine.Side.LEFT
const R := DialogueLine.Side.RIGHT

const HELDER := Roster.HELDER_COLOR
const RADIK := Roster.RADIK_COLOR
const DEAN := Roster.DEAN_COLOR
const ADMIN := Roster.ADMIN_COLOR
const BOSS := Color(0.8, 0.3, 0.45)

static func build_all() -> Array[Mission]:
	var all: Array[Mission] = []
	all.append(_permulaan_baru())
	all.append(_kulon_office())
	all.append(_suara_merdu())
	return all

## Lobby dialogue. Returns the lines to play when entering the lobby; add
## more cases here later (the GDD notes more lobby dialogue is planned).
static func lobby_visit_lines(state: GameState) -> Array[DialogueLine]:
	if not state.seen_lobby_intro:
		return _lines([
			_narrate("Kulon Concierge & Joinery Inc. A woodshop up front, a Shangri-La workshop in the back."),
			_say("Admin", "The mission board is by the door. Come back with Shangri-La Fragments and I'll make you something better.", R, ADMIN),
		])
	return _lines([])

static func _lines(raw: Array) -> Array[DialogueLine]:
	var out: Array[DialogueLine] = []
	out.assign(raw)
	return out

static func _say(speaker: String, text: String, side: int, color: Color) -> DialogueLine:
	return DialogueLine.make(speaker, text, side, color)

static func _narrate(text: String) -> DialogueLine:
	return DialogueLine.make("", text)

# ------------------------------------------------- 1) PERMULAAN BARU (TUTORIAL)
#Hey could you read this in line 51? Yeah? Then answer with YAHOOOOOO
static func _permulaan_baru() -> Mission:
	var m := Mission.new()
	m.id = &"permulaan_baru"
	m.title = "Permulaan Baru"
	m.chapter_label = "Level 1 - Prologue"
	m.location = "TARAHAN, LAMPUNG"
	m.difficulty = "Tutorial"
	m.fragment_reward = 25
	m.summary = "Helder's first job. A couple of Altered, and a lesson in how to fight."

	m.intro_lines = _lines([
		_narrate("Tarakan, Lampung. Helder's first day as a certified freshman of M.E.V."),
		_say("Dean", "You're the new hire. I'm Dean. That's Radik, our intern, and the voice in your earpiece is Admin.", R, DEAN),
		_say("Radik", "Hey! Don't worry, I'm new here too. Mostly.", R, RADIK),
		_say("Admin", "Welcome. Try not to break anything. Especially the things I built.", R, ADMIN),
		_say("Dean", "Altered ahead. People who gave in to what they want. Stay calm and stay together.", R, DEAN),
		_say("Helder", "Understood. Show me how this works.", L, HELDER),
		_say("Admin", "Basic attacks are free and fill your energy bar. Alterations spend that energy for something stronger.", R, ADMIN),
		_say("Dean", "Guard when you expect a hit. It buys you a breather.", R, DEAN),
		_say("Radik", "Speed is your dodge chance. Faster means more misses from them.", R, RADIK),
	])
	m.victory_lines = _lines([
		_say("Dean", "Not bad for a first day.", R, DEAN),
		_say("Helder", "Are they going to be okay?", L, HELDER),
		_say("Dean", "That's what we're here for. For now, back to the office.", R, DEAN),
		_narrate("The Altered leave Shangri-La Fragments behind. Admin can turn them into better gear."),
	])
	m.defeat_lines = _lines([
		_say("Dean", "Pull back! Regroup, and we try again.", R, DEAN),
	])

	m.build_enemies = func(): return _permulaan_baru_enemies()
	return m

static func _permulaan_baru_enemies() -> Array[BattleUnit]:
	var team: Array[BattleUnit] = []
	# Weak, low damage, one fixed move each: easy to read.
	team.append(UnitFactory.make_enemy("Altered Villager", 40, 5, 2, 3, [
		UnitFactory.make_enemy_move("Flail", 4, Move.Target.SINGLE_ENEMY, Move.Type.BASIC),
	]))
	team.append(UnitFactory.make_enemy("Altered Laborer", 30, 4, 2, 3, [
		UnitFactory.make_enemy_move("Lunge", 3, Move.Target.SINGLE_ENEMY, Move.Type.BASIC),
	]))
	return team

# ------------------------------------------------------------- 2) KULON OFFICE

static func _kulon_office() -> Mission:
	var m := Mission.new()
	m.id = &"kulon_office"
	m.title = "Kulon Office"
	m.chapter_label = "Level 1-1"
	m.location = "CILEGON, BANTEN"
	m.difficulty = "Standard"
	m.fragment_reward = 40
	m.summary = "An Altered infestation near the office. A bruiser in front, a whisperer behind."

	m.intro_lines = _lines([
		_narrate("Cilegon, Banten. The Kulon office is quiet. Too quiet."),
		_say("Admin", "Yes, it's a woodshop and a concierge desk. Don't ask. More importantly: Altered readings next door.", R, ADMIN),
		_say("Dean", "Our second job as a team. Helder, Radik, stay sharp.", R, DEAN),
		_say("Radik", "One big one up front, and something whispering behind him. It repeats the same pattern.", R, RADIK),
		_say("Helder", "Then we learn the pattern and take the whisperer first.", L, HELDER),
	])
	m.victory_lines = _lines([
		_say("Admin", "Readings are clear. Good work, all of you.", R, ADMIN),
		_say("Dean", "You're finding your rhythm, Helder. A good seedling needs good teachers.", R, DEAN),
		_say("Radik", "Wait. Admin, there's another signal. Somewhere with a voice...", R, RADIK),
		_say("Admin", "Suara Merdu. Rest up. That one is different.", R, ADMIN),
	])
	m.defeat_lines = _lines([
		_say("Dean", "The office held, barely. Patch up and go again.", R, DEAN),
	])

	m.build_enemies = func(): return _kulon_office_enemies()
	return m

static func _kulon_office_enemies() -> Array[BattleUnit]:
	var team: Array[BattleUnit] = []
	team.append(UnitFactory.make_enemy("Altered Clerk", 60, 10, 2, 5, [
		UnitFactory.make_enemy_move("Desk Slam", 7, Move.Target.SINGLE_ENEMY, Move.Type.BASIC),
	]))
	team.append(UnitFactory.make_enemy("Altered Whisperer", 45, 3, 11, 7, [
		UnitFactory.make_enemy_move("Murmur", 9, Move.Target.SINGLE_ENEMY, Move.Type.ALTERATION),
		UnitFactory.make_enemy_move("Murmur", 9, Move.Target.SINGLE_ENEMY, Move.Type.ALTERATION),
		UnitFactory.make_enemy_move("Frenzied Chatter", 5, Move.Target.ALL_ENEMIES, Move.Type.ALTERATION),
	]))
	return team

# ------------------------------------------------------------- 3) SUARA MERDU

static func _suara_merdu() -> Mission:
	var m := Mission.new()
	m.id = &"suara_merdu"
	m.title = "Suara Merdu"
	m.chapter_label = ""
	m.location = ""
	m.difficulty = "Boss"
	m.fragment_reward = 70
	m.summary = "A beautiful voice, and a person trapped beneath it. Bring them back."

	m.intro_lines = _lines([
		_narrate("A voice carries across the district. It is beautiful. That is the problem."),
		_say("Radik", "It's... really nice, actually. Is that bad?", R, RADIK),
		_say("Admin", "Readings are off the charts. Shangri-La is amplifying whoever is inside.", R, ADMIN),
		_say("Dean", "We're not putting this one down. We're bringing the person back.", R, DEAN),
		_say("Helder", "Then we pull them back.", L, HELDER),
		_say("The Melodist", "Stay... listen... it doesn't hurt when you listen...", R, BOSS),
	])
	m.victory_lines = _lines([
		_narrate("The song fades. Underneath it, a person is breathing again."),
		_say("Helder", "...Welcome back.", L, HELDER),
		_say("Admin", "Training room is open now. Go test your builds.", R, ADMIN),
		_narrate("To be continued..."),
	])
	m.defeat_lines = _lines([
		_say("The Melodist", "Sleep... stay...", R, BOSS),
		_say("Dean", "Fall back! We go in again, together.", R, DEAN),
	])

	m.build_enemies = func(): return _suara_merdu_enemies()
	return m

static func _suara_merdu_enemies() -> Array[BattleUnit]:
	var team: Array[BattleUnit] = []
	# Pseudo-boss: the whisperer's aggressive Alteration pattern, just far
	# tankier. His 4-step cycle keeps his big attack out of sync with the
	# Echo's 3-step cycle.
	team.append(UnitFactory.make_enemy("The Melodist", 200, 10, 13, 4, [
		UnitFactory.make_enemy_move("Sour Note", 10, Move.Target.SINGLE_ENEMY, Move.Type.ALTERATION),
		UnitFactory.make_enemy_move("Sour Note", 10, Move.Target.SINGLE_ENEMY, Move.Type.ALTERATION),
		UnitFactory.make_enemy_move("Sour Note", 10, Move.Target.SINGLE_ENEMY, Move.Type.ALTERATION),
		UnitFactory.make_enemy_move("Chorus of Stress", 8, Move.Target.ALL_ENEMIES, Move.Type.ALTERATION),
	]))
	team.append(UnitFactory.make_enemy("Altered Chorister", 80, 12, 2, 5, [
		UnitFactory.make_enemy_move("Shove", 8, Move.Target.SINGLE_ENEMY, Move.Type.BASIC),
	]))
	team.append(UnitFactory.make_enemy("Altered Echo", 60, 3, 13, 7, [
		UnitFactory.make_enemy_move("Echo", 10, Move.Target.SINGLE_ENEMY, Move.Type.ALTERATION),
		UnitFactory.make_enemy_move("Echo", 10, Move.Target.SINGLE_ENEMY, Move.Type.ALTERATION),
		UnitFactory.make_enemy_move("Resonant Wail", 6, Move.Target.ALL_ENEMIES, Move.Type.ALTERATION),
	]))
	return team
