extends RefCounted
class_name EnemyLibrary
## The list behind the Enemy Encyclopedia. Every EnemyType file in
## data/enemies/ shows up automatically (training dummies don't). Regular enemies
## are always listed; a boss appears only after it has been met in a battle.
## Each enemy move is described by its `description` in the .tres plus an
## auto-built effect list ("5 damage, +1 Gloop").

const DIR := "res://data/enemies"

static var _all: Array[EnemyType] = []

static func all() -> Array[EnemyType]:
	if _all.is_empty():
		_load()
	return _all

static func _load() -> void:
	var dir := DirAccess.open(DIR)
	if dir == null:
		return
	var names: PackedStringArray = []
	for f in dir.get_files():
		var n := f.trim_suffix(".remap") # exported builds rename resources
		if n.ends_with(".tres") or n.ends_with(".res"):
			names.append(n)
	names.sort()
	var found: Array[EnemyType] = []
	for n in names:
		var res := load("%s/%s" % [DIR, n])
		if res is EnemyType and not res.is_dummy:
			found.append(res)
	# regular enemies first (A-Z), bosses after
	found.sort_custom(func(a: EnemyType, b: EnemyType):
		if a.is_boss != b.is_boss:
			return not a.is_boss
		return a.display_name < b.display_name)
	_all = found

static func visible_for(state: GameState) -> Array[EnemyType]:
	var out: Array[EnemyType] = []
	for e in all():
		if not e.is_boss or state.has_met(e.enemy_id()):
			out.append(e)
	return out

## "Slosh : Memukul satu target dengan lumpur lengket (5 damage, +1 Gloop)"
static func move_line(move: Move) -> String:
	var parts: PackedStringArray = []
	if move.deals_damage and move.power > 0:
		var dmg := "%d damage" % move.power if move.hits <= 1 else "%d x %d damage" % [move.hits, move.power]
		if move.target_type == Move.Target.ALL_ENEMIES:
			dmg += " ke semua"
		parts.append(dmg)
	for a in move.inflicts:
		var def := StatusDefs.get_def(a.kind)
		var count := a.stacks * (move.hits if move.inflicts_per_hit else 1)
		parts.append(("+%d %s" % [count, def.label]) if def.max_stacks > 1 else def.label)
	if move.stun_turns > 0:
		parts.append("Stun")
	for a in move.grants_self:
		parts.append("%s (diri sendiri)" % StatusDefs.get_def(a.kind).label)
	if move.effects_ignore_dodge:
		parts.append("tak bisa dihindari")
	if move.target_type == Move.Target.ALL_ENEMIES and not (move.deals_damage and move.power > 0):
		parts.append("ke semua")
	var tail := "" if parts.is_empty() else " (%s)" % ", ".join(parts)
	var text := move.description if move.description != "" else "-"
	return "%s : %s%s" % [move.move_name, text, tail]
