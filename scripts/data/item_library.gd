extends RefCounted
class_name ItemLibrary
## Every craftable consumable (workshop > Preparation). Prices are Shangri-La
## Fragments. Effect numbers and Indonesian texts live here.

const MAX_STACK := 9 # most of one item you can carry

## Category flavor texts (shown above each group in the workshop).
const CATEGORY_FLAVOR := {
	"Revive Items": "Barang yang membantu agen lapangan kembali berdiri",
	"Heal Items": "Penanganan pertama mutakhir untuk kecelakaan dan luka",
	"Booster Items": "Dibuat khusus sebagai booster pengguna alteration dan atlet",
	"Admin's Special": "Kalian tahu kalo ini mungkin agak bahaya, kan?",
}

static var _items: Array[Item] = []

static func all() -> Array[Item]:
	if _items.is_empty():
		_build()
	return _items

static func get_item(item_id: String) -> Item:
	for i in all():
		if i.id == item_id:
			return i
	return null

static func categories() -> PackedStringArray:
	return PackedStringArray(["Revive Items", "Heal Items", "Booster Items", "Admin's Special"])

static func in_category(category: String) -> Array[Item]:
	var out: Array[Item] = []
	for i in all():
		if i.category == category:
			out.append(i)
	return out

static func _add(item_id: String, name: String, category: String, cost: int, desc: String,
		heal_pct: float = 0.0, revive: bool = false, energy: int = 0, buff: StatusDefs.Kind = -1 as StatusDefs.Kind) -> void:
	var i := Item.new()
	i.id = item_id
	i.item_name = name
	i.category = category
	i.cost = cost
	i.description = desc
	i.heal_pct = heal_pct
	i.heal_amount = 0
	i.revive = revive
	i.energy_gain = energy
	if int(buff) >= 0:
		i.buffs.append(StatusApplication.make(buff))
	_items.append(i)

static func _build() -> void:
	_add("meg_p3k", "M.E.G-P3K", "Revive Items", 20,
		"Menghidupkan kembali rekan yang tumbang dengan 15% HP.", 15.0, true)
	_add("meg_r3v", "M.E.G-R3V", "Revive Items", 35,
		"Menghidupkan kembali rekan yang tumbang dengan 30% HP.", 30.0, true)

	_add("med_njus", "Med-Njus", "Heal Items", 5,
		"Memulihkan 20% HP.", 20.0)
	_add("evvac_emk", "EVVAC-EMK", "Heal Items", 15,
		"Memulihkan 40% HP.", 40.0)

	_add("kratingden", "Kratingden", "Booster Items", 25,
		"Memulihkan 10% HP dan memberi 2 Energy.", 10.0, false, 2)
	_add("bir_pletok", "Druen \"Bir Pletok\"", "Booster Items", 55,
		"Memulihkan 10% HP dan memberi 4 Energy.", 10.0, false, 4)

	_add("inj_cqb", "Inj-CQB", "Admin's Special", 50,
		"Buff \"Inj-CQB\": +5 Speed dan +10 Strength selama 3 giliran. Setelah habis, penerima kehilangan 10% HP maksimal.",
		0.0, false, 0, StatusDefs.Kind.INJ_CQB)
	_add("inj_acb", "Inj-ACB", "Admin's Special", 50,
		"Buff \"Inj-ACB\": +15 Capability selama 3 giliran. Setelah habis, penerima kehilangan 10% HP maksimal.",
		0.0, false, 0, StatusDefs.Kind.INJ_ACB)
