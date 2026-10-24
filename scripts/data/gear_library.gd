extends RefCounted
class_name GearLibrary
## Every craftable weapon. Names/numbers are placeholders - edit freely.
## Costs: tier 1 = 30 fragments, tier 2 = 80. (Mission rewards are in
## MissionLibrary: 25 / 40 / 70 on first clear.)

static var _cache: Array[Weapon] = []

static func all() -> Array[Weapon]:
	if _cache.is_empty():
		_build()
	return _cache

static func get_weapon(weapon_id: String) -> Weapon:
	for w in all():
		if w.id == weapon_id:
			return w
	return null

## Weapons for one character, base weapon first, then by tier.
static func for_character(character_id: String) -> Array[Weapon]:
	var out: Array[Weapon] = []
	for w in all():
		if w.owner_id == character_id:
			out.append(w)
	out.sort_custom(func(a: Weapon, b: Weapon): return a.tier < b.tier)
	return out

static func _build() -> void:
	# make(id, name, owner, tier, cost, basic move name, +HP, +ATK, +CAP, +SPD, description)

	# --- Helder: electric baton -------------------------------------------
	_cache.append(Weapon.make("helder_baton", "Electric Baton", "helder", 0, 0, "Baton Strike",
		0, 0, 0, 0, "Mid-range workshop baton powered by a Shangri-La Fragment."))
	_cache.append(Weapon.make("helder_baton_2", "Reinforced Arc Baton", "helder", 1, 30, "Arc Strike",
		0, 3, 2, 0, "Better conductors and a stronger core."))
	_cache.append(Weapon.make("helder_baton_3", "Shangri-La Arc Baton", "helder", 2, 80, "Surge Strike",
		10, 6, 4, 0, "A baton built around a full fragment. It hums when held."))

	# --- Radik: custom parang ---------------------------------------------
	_cache.append(Weapon.make("radik_parang", "Custom Parang", "radik", 0, 0, "Parang Slash",
		0, 0, 0, 0, "Admin's custom blade. Splits into a blade and a throwing knife."))
	_cache.append(Weapon.make("radik_parang_2", "Split-Edge Parang", "radik", 1, 30, "Split Slash",
		0, 2, 0, 3, "Lighter and faster to separate."))
	_cache.append(Weapon.make("radik_parang_3", "Fragment-Forged Parang", "radik", 2, 80, "Forged Slash",
		0, 4, 0, 6, "Forged straight from fragments. Almost weightless."))

	# --- Dean: baton and riot shield --------------------------------------
	_cache.append(Weapon.make("dean_riot", "Baton & Riot Shield", "dean", 0, 0, "Baton Swing",
		0, 0, 0, 0, "Anti-Altered riot gear, modified by Admin."))
	_cache.append(Weapon.make("dean_riot_2", "Reinforced Riot Set", "dean", 1, 30, "Braced Swing",
		20, 2, 0, 0, "Thicker plating, heavier swing."))
	_cache.append(Weapon.make("dean_riot_3", "Anti-Altered Riot Set Mk II", "dean", 2, 80, "Breaker Swing",
		40, 4, 0, 0, "Tuned to take hits from the worst of them."))

	# --- WYG-01: Admin's mechanoid ----------------------------------------
	_cache.append(Weapon.make("wyg_frame", "WYG-01 Standard Frame", "wyg01", 0, 0, "Servo Strike",
		0, 0, 0, 0, "Admin's field mechanoid, powered by a Shangri-La Fragment."))
	_cache.append(Weapon.make("wyg_frame_2", "WYG-01 Servo Upgrade", "wyg01", 1, 30, "Piston Strike",
		10, 0, 3, 0, "Sharper servos and a better power feed."))
	_cache.append(Weapon.make("wyg_frame_3", "WYG-01 Fragment Core", "wyg01", 2, 80, "Core Strike",
		20, 2, 6, 0, "A second fragment fitted into the chassis."))
