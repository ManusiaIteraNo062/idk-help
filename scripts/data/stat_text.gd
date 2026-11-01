extends RefCounted
class_name StatText
## "+10 HP  +5 STR  -5 SPD" text shared by upgrades and equipment.
## STR = Strength (the Attack stat), CAP = Capability, SPD = Speed.

static func bonuses(hp: int, str_: int, cap: int, spd: int) -> String:
	var parts: PackedStringArray = []
	if hp != 0:
		parts.append("%+d HP" % hp)
	if str_ != 0:
		parts.append("%+d STR" % str_)
	if cap != 0:
		parts.append("%+d CAP" % cap)
	if spd != 0:
		parts.append("%+d SPD" % spd)
	return "  ".join(parts)
