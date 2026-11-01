extends RefCounted
class_name Skill
## One Alteration skill as shown in the workshop's Skill Knowledge tab.
## Base skills are known from the start; unlockable ones are bought with
## Fragments. `build_moves()` makes FRESH Move objects for a battle (most
## skills are one move; Cannon is one skill but one menu entry per energy level).

const UNLOCK_COST := 75

var id: String = ""
var owner_id: String = ""
var display_name: String = ""
var unlockable: bool = false
var cost: int = 0
var cost_text: String = ""      # e.g. "1 Energy, 2x per misi"
var summary: String = ""        # Indonesian: what it does
var formula: String = ""        # Indonesian: the damage / effect calculation
var builder: Callable           # () -> Array[Move]
var preview: Callable           # (stats: Dictionary) -> String, optional

func build_moves() -> Array[Move]:
	var out: Array[Move] = []
	out.assign(builder.call())
	return out

## "Saat ini: ..." line using the character's current stats (base + upgrade + equipment).
func preview_text(stats: Dictionary) -> String:
	if preview.is_valid():
		return preview.call(stats)
	var moves := build_moves()
	if moves.is_empty() or not moves[0].deals_damage:
		return ""
	var m := moves[0]
	var per_hit := m.damage_per_hit(stats["attack"], stats["capability"], stats["speed"])
	var t := "Saat ini: %d damage" % per_hit
	if m.hits > 1:
		t += " x %d" % m.hits
	if m.target_type == Move.Target.ALL_ENEMIES:
		t += " ke semua musuh"
	return t
