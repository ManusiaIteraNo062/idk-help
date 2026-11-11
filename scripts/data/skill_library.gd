extends RefCounted
class_name SkillLibrary
## Every Alteration skill (the Alteration port). All numbers are rounded UP.
## Strength = the Attack stat. Texts shown in the workshop are Indonesian.
## To tune a skill: change the numbers in its builder, and its `formula` text.

static var _all: Array[Skill] = []

static func all() -> Array[Skill]:
	if _all.is_empty():
		_build()
	return _all

static func get_skill(skill_id: String) -> Skill:
	for s in all():
		if s.id == skill_id:
			return s
	return null

## Base skills first, then unlockable ones, in the order listed below.
static func for_character(character_id: String) -> Array[Skill]:
	var out: Array[Skill] = []
	for s in all():
		if s.owner_id == character_id:
			out.append(s)
	return out

# ---- builders ---------------------------------------------------------------

static func _alt(name: String, cost: int, target: Move.Target) -> Move:
	var m := Move.new()
	m.move_name = name
	m.type = Move.Type.ALTERATION
	m.energy_cost = cost
	m.target_type = target
	m.power = 0
	m.scaling_mult = 0.0
	return m

static func _dmg(m: Move, power: int, stat: Move.Stat, mult: float) -> Move:
	m.power = power
	m.scaling_stat = stat
	m.scaling_mult = mult
	return m

static func _add(skill_id: String, owner: String, name: String, unlockable: bool, cost_text: String,
		summary: String, formula: String, builder: Callable, preview: Callable = Callable()) -> void:
	var s := Skill.new()
	s.id = skill_id
	s.owner_id = owner
	s.display_name = name
	s.unlockable = unlockable
	s.cost = Skill.UNLOCK_COST if unlockable else 0
	s.cost_text = cost_text
	s.summary = summary
	s.formula = formula
	s.builder = builder
	s.preview = preview
	_all.append(s)

static func _build() -> void:
	var STR := Move.Stat.STRENGTH
	var CAP := Move.Stat.CAPABILITY
	var SPD := Move.Stat.SPEED
	var T := Move.Target

	# ======================= Helder - Oxypetalum =======================
	_add("h_strengthen", "helder", "Strengthen", false, "1 Energy, 2x per misi",
		"Cahaya hangat Oxypetalum menyelimuti Helder, menguatkan setiap pukulannya sampai misi selesai.",
		"Strength + (Capability / 4). Bisa dipakai 2 kali dan bertumpuk.",
		func():
			var m := _alt("Strengthen", 1, T.SELF)
			m.max_uses_per_battle = 2
			m.grants_self.append(StatusApplication.make_with(StatusDefs.Kind.STRENGTHEN, 0, 0.25))
			return [m],
		func(s: Dictionary): return "Saat ini: +%d Strength" % Move.round_up(s["capability"] * 0.25))
	_add("h_condemn", "helder", "Condemn", false, "2 Energy",
		"Menghantamkan seberkas cahaya yang menghukum satu musuh. Jika musuh tumbang, cahayanya memulihkan Helder.",
		"Damage = 20 + Strength. Pulih 10% HP maks jika musuh tumbang.",
		func(): 
			var m := _dmg(_alt("Condemn", 2, T.SINGLE_ENEMY), 20, STR, 1.0)
			m.heal_self_on_kill_pct = 10.0
			return [m])
	_add("h_absorption", "helder", "Absorption", false, "3 Energy",
		"Meledakkan kilau putih ke semua musuh, lalu menyerap sebagian cahayanya kembali menjadi tenaga.",
		"Damage = 10 + (Strength / 5) ke semua musuh. Pulih 30% dari damage yang diberikan.",
		func():
			var m := _dmg(_alt("Absorption", 3, T.ALL_ENEMIES), 10, STR, 0.2)
			m.lifesteal = 0.3
			return [m])
	_add("h_rejuvenate", "helder", "Rejuvenate", true, "2 Energy",
		"Menebar kelopak cahaya yang menyembuhkan seluruh tim.",
		"Pulih = Capability / 2 untuk setiap anggota tim.",
		func():
			var m := _alt("Rejuvenate", 2, T.ALL_ALLIES)
			m.is_heal = true
			m.heal_flat_per_cap = 0.5
			return [m],
		func(s: Dictionary): return "Saat ini: pulih %d HP tiap anggota" % Move.round_up(s["capability"] * 0.5))
	_add("h_flicking", "helder", "Flicking", true, "1 Energy",
		"Menjentikkan percikan cahaya kecil yang melesat ke satu musuh.",
		"Damage = Strength.",
		func(): return [_dmg(_alt("Flicking", 1, T.SINGLE_ENEMY), 0, STR, 1.0)])

	# ======================= Radik - Palesa =======================
	_add("r_ravaging", "radik", "Ravaging", false, "3 Energy",
		"Serangan bertubi yang cepat, menyapu semua musuh dalam satu rentetan.",
		"Damage = (10 + (Speed / 2)) x 2 ke semua musuh.",
		func(): return [_dmg(_alt("Ravaging", 3, T.ALL_ENEMIES), 20, SPD, 1.0)]) # (10 + Speed/2) x 2 = 20 + Speed
	_add("r_one_two", "radik", "One-Two", false, "1 Energy",
		"Dua tebasan beruntun yang datang lebih cepat dari kedipan mata.",
		"Damage = 10 + (Capability / 2), sebanyak 2 kali.",
		func():
			var m := _dmg(_alt("One-Two", 1, T.SINGLE_ENEMY), 10, CAP, 0.5)
			m.hits = 2
			return [m])
	_add("r_heroik", "radik", "Stance \"Heroik\"", false, "1 Energy, 2x per misi",
		"Radik berdiri tegap dalam Guard Stance sambil mengumpulkan tenaga untuk giliran berikutnya.",
		"Guard sampai ronde berikutnya. +3 Energy di awal giliran berikutnya.",
		func():
			var m := _alt("Stance \"Heroik\"", 1, T.SELF)
			m.max_uses_per_battle = 2
			m.self_guard = true
			m.grants_self.append(StatusApplication.make_with(StatusDefs.Kind.ENERGIZED, 3))
			return [m],
		func(_s: Dictionary): return "")
	_add("r_kilau", "radik", "Stance \"Kilau\"", true, "1 Energy, 1x per misi",
		"Radik menyalakan semangatnya, bergerak makin ringan dan makin cepat sampai misi selesai.",
		"Speed + (Capability / 4).",
		func():
			var m := _alt("Stance \"Kilau\"", 1, T.SELF)
			m.max_uses_per_battle = 1
			m.grants_self.append(StatusApplication.make_with(StatusDefs.Kind.SWIFT, 0, 0.25))
			return [m],
		func(s: Dictionary): return "Saat ini: +%d Speed" % Move.round_up(s["capability"] * 0.25))
	_add("r_berandalan", "radik", "\"Berandalan\"", true, "4 Energy",
		"Menerjang nekat dengan seluruh tenaga dan kecepatan. Jika musuh tumbang, napas Radik kembali.",
		"Damage = Capability + (Speed x 1.5). +2 Energy jika musuh tumbang.",
		func():
			var m := _dmg(_alt("\"Berandalan\"", 4, T.SINGLE_ENEMY), 0, CAP, 1.0)
			m.speed_mult = 1.5
			m.energy_on_kill = 2
			return [m])

	# ======================= Dean - Taksaka =======================
	_add("d_enchain", "dean", "Enchain", false, "1 Energy",
		"Melilitkan rantai ke satu musuh, menghantamnya, lalu mengikatnya dalam Stun.",
		"Damage = Strength, lalu Stun target.",
		func():
			var m := _dmg(_alt("Enchain", 1, T.SINGLE_ENEMY), 0, STR, 1.0)
			m.stun_turns = 1
			return [m])
	_add("d_eruption", "dean", "Eruption", false, "3 Energy",
		"Membuat ledakan rantai dari bawah tanah ke semua musuh.",
		"Damage = 20 + (Capability x 4) ke semua musuh.",
		func(): return [_dmg(_alt("Eruption", 3, T.ALL_ENEMIES), 20, CAP, 4.0)])
	_add("d_encompass", "dean", "Encompass", false, "2 Energy",
		"Rantai melingkar mengurung semua musuh dalam Stun, sementara Dean menarik napas.",
		"Stun semua musuh. Dean pulih 15 + (Capability / 4, dibulatkan ke bawah) HP.",
		func():
			var m := _alt("Encompass", 2, T.ALL_ENEMIES)
			m.deals_damage = false
			m.stun_turns = 1
			m.self_heal_flat = 15
			m.self_heal_per_cap = 0.25
			return [m],
		func(s: Dictionary): return "Saat ini: pulih %d HP" % (15 + floori(s["capability"] * 0.25)))
	_add("d_onslaught", "dean", "Onslaught", true, "2 Energy",
		"Tiga cambukan rantai berturut-turut ke satu musuh.",
		"Damage = 13 + (Strength / 2), sebanyak 3 kali. Jika HP target di bawah 30% setelah pukulan terakhir, Dean mendapat Energized.",
		func():
			var m := _dmg(_alt("Onslaught", 2, T.SINGLE_ENEMY), 13, STR, 0.5)
			m.hits = 3
			m.energize_if_target_below_hp_pct = 0.3
			return [m])
	_add("d_overcome", "dean", "Overcome", true, "1 Energy",
		"Merantai satu musuh dalam Stun dan langsung masuk Guard Stance.",
		"Stun target. Dean masuk posisi Guard.",
		func():
			var m := _alt("Overcome", 1, T.SINGLE_ENEMY)
			m.deals_damage = false
			m.stun_turns = 1
			m.self_guard = true
			return [m],
		func(_s: Dictionary): return "")

	# ======================= WYG-01 - Synthetica =======================
	_add("w_cannon", "wyg01", "Cannon", false, "2-5 Energy (pilih sendiri)",
		"Menembakkan meriam; makin banyak Energy yang disalurkan, makin dahsyat ledakannya.",
		"Damage = (Capability / 2) x Energy yang dipakai. Tambahan +20 damage jika memakai 4 Energy atau lebih.",
		func():
			var out: Array[Move] = []
			for e in range(2, 6):
				out.append(_dmg(_alt("Cannon (%d Energy)" % e, e, T.SINGLE_ENEMY), 20 if e >= 4 else 0, CAP, 0.5 * e))
			return out,
		func(s: Dictionary):
			var parts: PackedStringArray = []
			for e in range(2, 6):
				parts.append("%d EN = %d" % [e, Move.round_up((20 if e >= 4 else 0) + s["capability"] * 0.5 * e)])
			return "Saat ini: " + ", ".join(parts))
	_add("w_field_heal", "wyg01", "Field Heal", false, "1 Energy",
		"Melepaskan nanobot medis yang menyembuhkan satu anggota tim.",
		"Pulih = 20% HP maksimal target.",
		func():
			var m := _alt("Field Heal", 1, T.SINGLE_ALLY)
			m.is_heal = true
			m.heal_pct_base = 20.0
			return [m],
		func(_s: Dictionary): return "")
	_add("w_booster", "wyg01", "Booster", false, "2 Energy",
		"Mengalirkan energi cadangan ke seluruh tim lewat modul booster.",
		"+1 Energy untuk semua anggota tim (termasuk pemakai).",
		func():
			var m := _alt("Booster", 2, T.ALL_ALLIES)
			m.grants_energy_allies = 1
			return [m],
		func(_s: Dictionary): return "")
	_add("w_javelin", "wyg01", "Javelin", true, "2 Energy",
		"Melontarkan lembing berujung Fragment; musuh yang sudah lemah akan terkena Stun.",
		"Damage = 15 + (Capability / 3). Stun jika HP target < 50%.",
		func():
			var m := _dmg(_alt("Javelin", 2, T.SINGLE_ENEMY), 15, CAP, 1.0 / 3.0)
			m.stun_if_target_below_hp_pct = 0.5
			return [m])
	_add("w_firecracker", "wyg01", "Firecracker", true, "2 Energy",
		"Menembakkan Cluster Rocket yang menghujani area dua kali.",
		"Damage = 15 + (Capability / 10), sebanyak 2 kali ke semua musuh.",
		func():
			var m := _dmg(_alt("Firecracker", 2, T.ALL_ENEMIES), 15, CAP, 0.1)
			m.hits = 2
			return [m])
