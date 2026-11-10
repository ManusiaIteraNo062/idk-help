extends RefCounted
class_name GearLibrary
## Everything craftable with Shangri-La Fragments, except skills (SkillLibrary).
## Costs: Upgrade 100; Equipment 65 / 75 / 100 by how many stats it raises. Edit numbers freely.

const SLOTS := 5            # equipment slots per character
const UPGRADE_COST := 100

static var _upgrades: Array[Upgrade] = []
static var _equipment: Array[EquipmentItem] = []

# ---- upgrades -----------------------------------------------------------

static func upgrades() -> Array[Upgrade]:
	if _upgrades.is_empty():
		_build_upgrades()
	return _upgrades

static func get_upgrade(upgrade_id: String) -> Upgrade:
	for u in upgrades():
		if u.id == upgrade_id:
			return u
	return null

## One character's entries: base (no upgrade) first, then by tier.
static func upgrades_for(character_id: String) -> Array[Upgrade]:
	var out: Array[Upgrade] = []
	for u in upgrades():
		if u.owner_id == character_id:
			out.append(u)
	out.sort_custom(func(a: Upgrade, b: Upgrade): return a.tier < b.tier)
	return out

static func _build_upgrades() -> void:
	# make(id, name, owner, tier, cost, +HP, +STR, +CAP, +SPD, flavor text).with_passive(...)
	# Tier 1 = the 2nd upgrade (grants the passive for the whole mission), tier 2 = the last
	# (the passive, enhanced). Stats are the old tier numbers +30% rounded up, and
	# every upgrade gives some HP. A tier-2 upgrade can only be crafted after tier 1.
	var K := StatusDefs.Kind
	var base := "Perlengkapan bawaan, belum dimodifikasi."

	_upgrades.append(Upgrade.make("helder_baton", "Electric Baton", "helder", 0, 0, 0, 0, 0, 0, base))
	_upgrades.append(Upgrade.make("helder_baton_2", "Reinforce Baton", "helder", 1, UPGRADE_COST, 8, 4, 3, 0,
		"Mulai battle dengan efek Verlichting, yang membantu mendapatkan energi saat melakukan serangan.")
		.with_passive(K.VERLICHTING, 40, "Verlichting: 40% peluang mendapat 1 Energize setiap memakai Strike."))
	_upgrades.append(Upgrade.make("helder_baton_3", "110% Charged Baton", "helder", 2, UPGRADE_COST, 13, 8, 6, 0,
		"Meningkatkan output energi Baton")
		.with_passive(K.VERLICHTING, 55, "Verlichting (ditingkatkan): peluangnya menjadi 55%."))

	_upgrades.append(Upgrade.make("radik_parang", "Custom Parang", "radik", 0, 0, 0, 0, 0, 0, base))
	_upgrades.append(Upgrade.make("radik_parang_2", "Polished Blade", "radik", 1, UPGRADE_COST, 8, 3, 0, 4,
		"Mulai battle dengan efek Sakepeng, yang memperingan pergerakan penggunanya di setiap serangan")
		.with_passive(K.SAKEPENG, 3, "Sakepeng: setiap Strike menambah 1 stack (maks 3). Tiap stack memberi +2 Speed."))
	_upgrades.append(Upgrade.make("radik_parang_3", "Trifect Edge Orgast", "radik", 2, UPGRADE_COST, 16, 6, 0, 8,
		"Modifikasi legal dengan menggunakan Blueprint ORK.Co")
		.with_passive(K.SAKEPENG, 5, "Sakepeng (ditingkatkan): bisa menumpuk sampai 5 stack."))

	_upgrades.append(Upgrade.make("dean_riot", "Baton & Riot Shield", "dean", 0, 0, 0, 0, 0, 0, base))
	_upgrades.append(Upgrade.make("dean_riot_2", "Armor Refitting", "dean", 1, UPGRADE_COST, 26, 3, 0, 0,
		"Mulai battle dengan efek Beringin, membantu pengguna untuk memulihkan tenaga ditengah pertarungan")
		.with_passive(K.BERINGIN, 4, "Beringin: mendapat 1 Energy di awal giliran setiap 4 giliran."))
	_upgrades.append(Upgrade.make("dean_riot_3", "Energizer Core Mk2", "dean", 2, UPGRADE_COST, 52, 6, 0, 0,
		"Menggunakan Core experimental yang dimaterialisasi Admin")
		.with_passive(K.BERINGIN, 3, "Beringin (ditingkatkan): setiap 3 giliran."))

	_upgrades.append(Upgrade.make("wyg_frame", "WYG-01 Standard Frame", "wyg01", 0, 0, 0, 0, 0, 0, base))
	_upgrades.append(Upgrade.make("wyg_frame_2", "Reinforced Body", "wyg01", 1, UPGRADE_COST, 13, 0, 4, 0,
		"Mulai battle dengan efek Resonance, membuat chassis memperkuat diri sendiri ditengah pertarungan")
		.with_passive(K.RESONANCE, 3, "Resonance: setiap Strike menambah 1 stack (maks 3). Tiap stack memberi +3 Capability."))
	_upgrades.append(Upgrade.make("wyg_frame_3", "Shangri-la Knuckles", "wyg01", 2, UPGRADE_COST, 26, 3, 8, 0,
		"Tinju yang dibuat dan dilapisi Fragment")
		.with_passive(K.RESONANCE, 5, "Resonance (ditingkatkan): bisa menumpuk sampai 5 stack."))

## The upgrade you must own before this one can be crafted (tier 2 needs tier 1), or null.
static func previous_upgrade(u: Upgrade) -> Upgrade:
	if u.tier < 2:
		return null
	for other in upgrades_for(u.owner_id):
		if other.tier == u.tier - 1:
			return other
	return null

# ---- equipment ----------------------------------------------------------

static func equipment() -> Array[EquipmentItem]:
	if _equipment.is_empty():
		_build_equipment()
	return _equipment

static func get_equipment(item_id: String) -> EquipmentItem:
	for e in equipment():
		if e.id == item_id:
			return e
	return null

static func _build_equipment() -> void:
	# make(id, name, +HP, +STR, +CAP, +SPD, flavor text) - price is set below by how many stats it raises.
	_equipment.append(EquipmentItem.make("thin_barrier", "Thin-Barrier Forcefield", 30, 0, 0, 0,
		"Perisai tipis anti-fisik dan anti-hujan oleh RTO.Co"))
	_equipment.append(EquipmentItem.make("mev_equipment", "M.E.V Mandated Agent Equipment", 20, 5, 5, 0,
		"Basic Equipment yang dikhususkan untuk Agen M.E.R"))
	_equipment.append(EquipmentItem.make("gatotkaca", "Sepatu Enhancer \"Gatotkaca\"", 10, 10, 0, -5,
		"Sepatu khusus tentara dari MB.Inc"))
	_equipment.append(EquipmentItem.make("keotop", "Kalung Hypervent \"Keotop\"", 0, 0, 5, 10,
		"Kalung dengan Fragment Shangri-la yang dibentuk ke permata Intan"))
	_equipment.append(EquipmentItem.make("weapon_holder", "All-Universal Weapon Holder", 0, 10, 0, 0,
		"Sarung senjata yang dapat berubah sesuai dengan senjata yang ditaruh"))
	_equipment.append(EquipmentItem.make("glazen_hart", "A-Enh \"Glazen Hart\" by M.E.V", 25, 0, 10, 0,
		"Shangri-la Fragment yang dibentuk menjadi penguat Alteration"))
	_equipment.append(EquipmentItem.make("haven_aan_zee", "A-Enh \"Haven aan zee\" by Indo-mer", 0, 5, 10, 0,
		"Medali yang dibentuk dari perak dengan simbol khas Betawi"))
	_equipment.append(EquipmentItem.make("bima_sakti", "A-Enh \"Bima Sakti\" by Dunya.Corp", 20, 0, 10, 0,
		"Tato tubuh yang bisa dilepas pasang dengan corak custom"))
	_equipment.append(EquipmentItem.make("jamu_palapa", "Dimensional Bev - Jamu cap Palapa", -20, 0, 20, 5,
		"Kantung Dimensional yang berisi Jamu Cabe"))
	# Price by how many stats the item RAISES (a drawback doesn't count):
	# 3 or more = 100, 2 = 75, 1 = 65.
	for e in _equipment:
		var raised := 0
		for v in [e.bonus_health, e.bonus_strength, e.bonus_capability, e.bonus_speed]:
			if v > 0:
				raised += 1
		e.cost = 100 if raised >= 3 else (75 if raised == 2 else 65)
