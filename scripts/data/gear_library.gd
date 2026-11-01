extends RefCounted
class_name GearLibrary
## Everything craftable with Shangri-La Fragments, except skills (SkillLibrary).
## Costs: Upgrade 125, Equipment 50. Edit numbers freely.

const SLOTS := 5            # equipment slots per character
const UPGRADE_COST := 125
const EQUIPMENT_COST := 50

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
	# make(id, name, owner, tier, cost, +HP, +STR, +CAP, +SPD, flavor text)
	# Bonus numbers are the old weapon-tier numbers, kept until you rebalance.
	var base := "Perlengkapan bawaan, belum dimodifikasi."

	_upgrades.append(Upgrade.make("helder_baton", "Electric Baton", "helder", 0, 0, 0, 0, 0, 0, base))
	_upgrades.append(Upgrade.make("helder_baton_2", "Reinforce Baton", "helder", 1, UPGRADE_COST, 0, 3, 2, 0,
		"Setup extender untuk memperkuat rangka"))
	_upgrades.append(Upgrade.make("helder_baton_3", "110% Charged Baton", "helder", 2, UPGRADE_COST, 10, 6, 4, 0,
		"Meningkatkan output energi Baton"))

	_upgrades.append(Upgrade.make("radik_parang", "Custom Parang", "radik", 0, 0, 0, 0, 0, 0, base))
	_upgrades.append(Upgrade.make("radik_parang_2", "Polished Blade", "radik", 1, UPGRADE_COST, 0, 2, 0, 3,
		"Menajamkan mata pisau dengan WDS-110"))
	_upgrades.append(Upgrade.make("radik_parang_3", "Trifect Edge Orgast", "radik", 2, UPGRADE_COST, 0, 4, 0, 6,
		"Modifikasi legal dengan menggunakan Blueprint ORK.Co"))

	_upgrades.append(Upgrade.make("dean_riot", "Baton & Riot Shield", "dean", 0, 0, 0, 0, 0, 0, base))
	_upgrades.append(Upgrade.make("dean_riot_2", "Armor Refitting", "dean", 1, UPGRADE_COST, 20, 2, 0, 0,
		"Modifikasi simplistik dari model armor anggota T.N.D.B"))
	_upgrades.append(Upgrade.make("dean_riot_3", "Energizer Core Mk2", "dean", 2, UPGRADE_COST, 40, 4, 0, 0,
		"Menggunakan Core experimental yang dimaterialisasi Admin"))

	_upgrades.append(Upgrade.make("wyg_frame", "WYG-01 Standard Frame", "wyg01", 0, 0, 0, 0, 0, 0, base))
	_upgrades.append(Upgrade.make("wyg_frame_2", "Reinforced Body", "wyg01", 1, UPGRADE_COST, 10, 0, 3, 0,
		"Menggunakan material permutasi untuk rangka robot"))
	_upgrades.append(Upgrade.make("wyg_frame_3", "Shangri-la Knuckles", "wyg01", 2, UPGRADE_COST, 20, 2, 6, 0,
		"Tinju yang dibuat dan dilapisi Fragment"))

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
	# make(id, name, +HP, +STR, +CAP, +SPD, flavor text) - cost is EQUIPMENT_COST for all.
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
	for e in _equipment:
		e.cost = EQUIPMENT_COST
