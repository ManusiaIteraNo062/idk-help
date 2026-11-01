extends SceneTree
## Headless smoke test:  godot --headless --path . --script res://tests/smoke_test.gd
## Checks mission loading and the status-effect rules. Prints PASS/FAIL lines.

var _fails := 0

func _check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("PASS  ", name)
	else:
		_fails += 1
		print("FAIL  ", name, "  ", detail)

func _unit(hp: int = 100) -> BattleUnit:
	var u := UnitFactory.make_unit("T", hp, 10, 10, 0)
	u.current_health = hp
	return u

func _init() -> void:
	_test_missions()
	_test_statuses()
	await _test_battle()
	_test_enemy_data()
	await _test_boss_two_actions()
	await _test_multi_wave()
	_test_gear_state()
	_test_skill_effects()
	_test_items()
	await _test_workshop_ui()
	await _test_battle_ui()
	await _test_title_and_flow()
	await _test_training()
	_test_misc_requests()
	await _test_tutorial_box()
	await _test_tutorial_in_flow()
	print("\n", "ALL PASSED" if _fails == 0 else "%d FAILED" % _fails)
	quit(1 if _fails > 0 else 0)

func _test_missions() -> void:
	var ms := MissionLibrary.build_all()
	_check("13 missions load", ms.size() == 13, str(ms.size()))
	var seen := {}
	for m in ms:
		seen[m.id] = true
		if m.wave_count() > 0:
			var e := m.build_wave(0)
			_check("%s wave 0 builds enemies" % m.id, e.size() > 0)
		_check("%s has intro" % m.id, m.intro_lines.size() > 0)
		if m.wave_count() > 0:
			_check("%s has defeat lines" % m.id, m.defeat_lines.size() > 0)
		for l in m.intro_lines + m.victory_lines:
			if l.text.length() > DialogueParser.MAX_CHARS + 120:
				_check("%s line length" % m.id, false, str(l.text.length()))
	_check("mission ids unique", seen.size() == ms.size())
	_check("mission 13 is story-only", ms[12].wave_count() == 0)
	var expected_waves := [2, 3, 1, 3, 3, 3, 3, 1, 3, 3, 3, 1]
	for i in 12:
		_check("mission %d has %d waves" % [i + 1, expected_waves[i]], ms[i].wave_count() == expected_waves[i], str(ms[i].wave_count()))
	_check("m1 wave1 = 2 Sloppy (A, B)", ms[0].build_wave(0).size() == 2 and ms[0].build_wave(0)[1].stats.character_name == "Sloppy Altered B")
	var m1w2 := ms[0].build_wave(1)
	_check("m1 wave2 = 2 Aggressive + 1 Sloppy", m1w2.size() == 3 and m1w2.filter(func(u): return u.stats.character_name.begins_with("Aggressive")).size() == 2)
	_check("m1 is Helder + Radik only", ms[0].party_ids == PackedStringArray(["helder", "radik"]) and ms[1].party_ids.is_empty())
	_check("m1 has a 2-page tutorial, others none", ms[0].tutorial_pages.size() == 2 and ms[1].tutorial_pages.is_empty())
	_check("4 Sloppy still get letters A-D (mission 4 wave 3)", ms[3].build_wave(2)[3].stats.character_name == "Sloppy Altered D")
	_check("m6 wave1 = 4 different mobs", ms[5].build_wave(0).size() == 4)
	_check("m3 boss wave", ms[2].build_wave(0)[0].stats.character_name == "H.P.A - Seaside" and ms[2].build_wave(0).size() == 4)
	_check("m12 is Red Sleigh, 2 actions", ms[11].build_wave(0)[0].actions_per_turn == 2 and ms[11].build_wave(0)[0].stats.max_health == 650)
	_check("rewards are 250", ms[0].fragment_reward == 250 and ms[11].fragment_reward == 250)
	var lines := DialogueParser.parse("Admin (via Drone): Hello.\n> Narration: with colon\nHelder [R]: Side.")
	_check("parser: 3 lines", lines.size() == 3)
	_check("parser: drone uses Admin color", lines[0].placeholder_color == Roster.ADMIN_COLOR)
	_check("parser: narration keeps colon", lines[1].speaker == "" and lines[1].text.contains(":"))
	_check("parser: side override", lines[2].side == DialogueLine.Side.RIGHT)
	var long_text := "Satu kalimat yang cukup panjang untuk diuji di sini. ".repeat(10)
	_check("parser: long line splits", DialogueParser.parse("> " + long_text).size() > 1)

func _test_statuses() -> void:
	var K := StatusDefs.Kind
	var u := _unit()
	u.add_status(K.FIRE, 4)
	_check("fire caps at 3 stacks", u.stacks_of(K.FIRE) == 3)
	u.tick_end_of_turn()
	_check("fire deals 5 x 3 then is removed", u.current_health == 85 and not u.has_status(K.FIRE), str(u.current_health))

	u = _unit()
	u.add_status(K.POISON)
	u.tick_end_of_turn()
	_check("poison tick 1", u.current_health == 98 and u.has_status(K.POISON))
	u.tick_end_of_turn()
	_check("poison tick 2 then gone", u.current_health == 96 and not u.has_status(K.POISON))

	u = _unit()
	u.add_status(K.GLOOP, 3)
	_check("gloop: +1 damage per 2 stacks (3 stacks = +1)", u.take_damage(10) == 11)
	u.add_status(K.GLOOP, 1) # now 4 stacks
	_check("gloop: 4 stacks = +2", u.take_damage(10) == 12)
	u.tick_end_of_turn()
	_check("gloop lasts 2 turns", u.has_status(K.GLOOP))
	u.tick_end_of_turn()
	_check("gloop expires", not u.has_status(K.GLOOP))

	u = _unit()
	u.add_status(K.TIME_DILATION)
	_check("time dilation halves", u.take_damage(10) == 5)
	u.add_status(K.STUN)
	_check("stun breaks time dilation", not u.has_status(K.TIME_DILATION))
	_check("stun costs a turn", u.consume_stun() and not u.consume_stun())

	u = _unit()
	var strike := u.basic_moves[0]
	var alt := Move.new()
	alt.type = Move.Type.ALTERATION
	alt.energy_cost = 2
	u.current_energy = 2
	_check("alteration usable at cost", u.can_use_move(alt))
	u.add_status(K.SAPPED)
	_check("sapped: cost +1", u.energy_cost_for(alt) == 3 and not u.can_use_move(alt))
	_check("sapped: basic still free", u.energy_cost_for(strike) == 0)

	u = _unit()
	u.add_status(K.STRENGTHEN, 1, 0, 9, false)
	_check("strengthen adds attack and is permanent", u.get_attack() == 19)
	u.tick_end_of_turn()
	_check("strengthen survives turn end", u.get_attack() == 19)

	# Buff given during own turn lasts through the next round.
	u = _unit()
	u.is_acting = true
	u.add_status(K.FLAME_WINGS)
	u.is_acting = false
	u.tick_end_of_turn()
	_check("flame wings survives granting turn's end", u.has_status(K.FLAME_WINGS))
	u.tick_end_of_turn()
	_check("flame wings expires next turn end", not u.has_status(K.FLAME_WINGS))

	u = _unit(10)
	u.add_status(K.FIRE, 3)
	u.tick_end_of_turn()
	_check("dot can kill", not u.is_alive())

func _test_battle() -> void:
	var bm := BattleManager.new()
	var hero := UnitFactory.make_unit("Hero", 100, 10, 10, 0)
	var foe_move := UnitFactory.make_enemy_move("Slosh", 5, Move.Target.SINGLE_ENEMY)
	foe_move.inflicts.append(StatusApplication.make(StatusDefs.Kind.GLOOP, 2))
	var wings := UnitFactory.make_enemy_move("Flap", 0, Move.Target.SINGLE_ENEMY)
	wings.deals_damage = false
	wings.grants_self.append(StatusApplication.make(StatusDefs.Kind.FLAME_WINGS))
	var foe := UnitFactory.make_enemy("Foe", 500, 5, 5, 0, [foe_move, wings])
	var team: Array[BattleUnit] = [hero]
	bm.player_team = team
	var enemies: Array[BattleUnit] = [foe]
	bm.enemy_team = enemies
	root.add_child(bm)
	for u in team + enemies:
		root.add_child(u)
	await process_frame

	var logs: Array[String] = []
	bm.battle_log.connect(func(t): logs.append(t))
	var turns := [0]
	bm.player_turn_started.connect(func(unit, actions):
		turns[0] += 1
		var act := {"type": "basic", "move": actions["basic"][0], "targets": [foe]}
		bm.submit_player_action.call_deferred(act)
	)
	bm.start_battle()
	for i in 6:
		await process_frame
	var text := "\n".join(logs)
	_check("battle: enemy inflicts Gloop on hit", text.contains("afflicted with Gloop"), text.substr(0, 300))
	_check("battle: Flame Wings granted", text.contains("gains Flame Wings"))
	_check("battle: hero attacked into Flame Wings and burned", text.contains("Fire damage"), text.substr(0, 600))
	_check("battle: statuses shown on hero", hero.has_status(StatusDefs.Kind.GLOOP) or hero.current_health < 100)
	print("--- sample log ---\n", text.substr(0, 700))

func _enemy(id: String) -> BattleUnit:
	var t := load("res://data/enemies/%s.tres" % id) as EnemyType
	var u := t.build_unit()
	u.current_health = u.stats.max_health
	return u

func _test_enemy_data() -> void:
	var hp := {"tough_altered": 200, "aggressive_altered": 75, "loud_altered": 120, "faraway_altered": 75,
		"sloppy_altered": 120, "hpa_seaside": 550, "hpa_dawnbreak": 1000, "hpa_red_sleigh": 650}
	for id in hp:
		var u := _enemy(id)
		_check("%s HP %d" % [id, hp[id]], u.stats.max_health == hp[id])
	# Mob AI: big (cooldown) move first when ready, then the basic one while it cools down.
	var tough := _enemy("tough_altered")
	var first: Move = tough.moveset.choose(tough)
	_check("tough opens with Ram (big, ready)", first.move_name == "Ram")
	tough.start_cooldown(first)
	tough.tick_cooldowns() # end of the turn Ram was used
	var seq: Array[String] = []
	for i in 4:
		var m: Move = tough.moveset.choose(tough)
		seq.append(m.move_name)
		tough.start_cooldown(m)
		tough.tick_cooldowns()
	_check("Ram cooldown 2 = Shove, Shove, Ram, Shove", seq == ["Shove", "Shove", "Ram", "Shove"], str(seq))
	# Fixed damage: Shove hits for exactly 7 (crit = 10).
	var bm := BattleManager.new()
	var shove: Move = tough.moveset.moves[0]
	var hero := _unit(1000)
	var dmg := bm._resolve_hit_for_test(tough, shove, hero)
	_check("Shove deals fixed 7 (or 10 on crit)", dmg == 7 or dmg == 10, str(dmg))
	# Boss RANDOM: only ever picks off-cooldown moves.
	var boss := _enemy("hpa_seaside")
	boss.start_cooldown(boss.moveset.moves[2])
	var ok := true
	for i in 40:
		if boss.moveset.choose(boss).move_name == "Lashing":
			ok = false
	_check("boss never picks a move on cooldown", ok)

func _await_frames(n: int) -> void:
	for i in n:
		await process_frame

func _test_boss_two_actions() -> void:
	var bm := BattleManager.new()
	var hero := UnitFactory.make_unit("Hero", 100000, 10, 10, 0)
	var boss := _enemy("hpa_dawnbreak")
	var team: Array[BattleUnit] = [hero]
	bm.player_team = team
	var enemies: Array[BattleUnit] = [boss]
	bm.enemy_team = enemies
	root.add_child(bm)
	for u in team + enemies:
		root.add_child(u)
	await process_frame
	var logs: Array[String] = []
	bm.battle_log.connect(func(t): logs.append(t))
	var rounds_done := [0]
	bm.round_started.connect(func(n): rounds_done[0] = n)
	bm.player_turn_started.connect(func(unit, actions):
		var g := {"type": "guard", "targets": []}
		bm.submit_player_action.call_deferred(g)
	)
	bm.start_battle()
	await _await_frames(40)
	var text := "\n".join(logs)
	var round1 := text.split("--- Round 2 ---")[0]
	var boss_lines := 0
	for l in round1.split("\n"):
		if l.begins_with("H.P.A - Dawnbreak uses"):
			boss_lines += 1
	_check("boss makes 2 attacks in a turn", boss_lines >= 2, "attack lines in round 1: %d\n%s" % [boss_lines, round1])
	_check("boss turns advance", rounds_done[0] >= 3, str(rounds_done[0]))
	bm.queue_free()

func _test_multi_wave() -> void:
	var m := (MissionLibrary.build_all())[0]
	var bm := BattleManager.new()
	var hero := UnitFactory.make_unit("Hero", 100000, 5000, 10, 0)
	var team: Array[BattleUnit] = [hero]
	bm.player_team = team
	var enemies: Array[BattleUnit] = []
	enemies.assign(m.build_wave(0))
	bm.enemy_team = enemies
	bm.wave_count = m.wave_count()
	bm.wave_factory = func(i: int): return m.build_wave(i)
	root.add_child(bm)
	for u in team + enemies:
		root.add_child(u)
	await process_frame
	var state := {"waves": 0, "ended": false, "won": false}
	bm.wave_started.connect(func(units): state["waves"] += 1)
	bm.battle_ended.connect(func(won): state["ended"] = true; state["won"] = won)
	bm.player_turn_started.connect(func(unit, actions):
		var alive := bm.enemy_team.filter(func(e): return e.is_alive())
		var act := {"type": "basic", "move": actions["basic"][0], "targets": [alive[0]]}
		bm.submit_player_action.call_deferred(act)
	)
	bm.start_battle()
	for i in 600:
		await process_frame
		if state["ended"]:
			break
	_check("multi-wave: wave 2 spawned", state["waves"] == 1, str(state))
	_check("multi-wave: ends with a win after the last wave", state["ended"] and state["won"] and bm.current_wave == 2, str(state))
	_check("multi-wave: new wave nodes are in the tree", bm.enemy_team[0].is_inside_tree())

# ---------------------------------------------------------------------------
# Workshop / gear / skills
# ---------------------------------------------------------------------------

func _state_all_skills(fragments: int = 100000) -> GameState:
	var st := GameState.new()
	st.ensure_defaults()
	st.fragments = fragments
	for sk in SkillLibrary.all():
		st.learn_skill(sk)
	return st

func _find_move(unit: BattleUnit, move_name: String) -> Move:
	for m in unit.alteration_moves:
		if m.move_name == move_name:
			return m
	return null

## Builds the real party (all skills known) plus N training dummies.
func _arena(dummies: int = 2, dummy_hp: int = 1000) -> Dictionary:
	var bm := BattleManager.new()
	bm.crit_chance = 0.0
	var team := UnitFactory.make_player_team(_state_all_skills())
	var foes: Array[BattleUnit] = []
	for i in dummies:
		foes.append(UnitFactory.make_enemy("Dummy %d" % i, dummy_hp, 0, 0, 0, [] as Array[Move]))
	bm.player_team = team
	bm.enemy_team = foes
	root.add_child(bm)
	for u in team + foes:
		root.add_child(u)
	return {"bm": bm, "team": team, "foes": foes, "helder": team[0], "radik": team[1], "dean": team[2], "wyg": team[3]}

func _cleanup(a: Dictionary) -> void:
	for u in a["team"] + a["foes"]:
		u.queue_free()
	a["bm"].queue_free()

func _lost(u: BattleUnit) -> int:
	return u.stats.max_health - u.current_health

func _test_gear_state() -> void:
	_check("round_up: 12.2 -> 13, 3.0000000000000004 -> 3", Move.round_up(12.2) == 13 and Move.round_up(3.0000000000000004) == 3)
	var st := GameState.new()
	st.ensure_defaults()
	st.fragments = 2000
	var base := st.stats_for("helder")
	var d = Roster.get_def("helder")
	_check("base stats come from Roster", base["health"] == d.health and base["attack"] == d.attack)

	var up := GearLibrary.get_upgrade("helder_baton_2")
	_check("upgrade costs 125 and equips", st.buy_upgrade(up) and st.fragments == 1875 and st.equipped_id("helder") == "helder_baton_2")
	_check("upgrade adds stats", st.stats_for("helder")["attack"] == d.attack + up.bonus_strength)
	_check("upgrade does not rename Basic attack", UnitFactory.make_player_team(st)[0].basic_moves[0].move_name == "Drabo")
	_check("equipping base entry removes the upgrade", st.equip_upgrade("helder", "helder_baton") and st.stats_for("helder")["attack"] == d.attack)
	_check("can't equip an upgrade you don't own", not st.equip_upgrade("helder", "helder_baton_3"))

	st.fragments = 2000
	var items := GearLibrary.equipment()
	_check("9 equipment items", items.size() == 9)
	for i in 6:
		st.buy_gear("helder", items[i])
	_check("5 slots: 6th item owned but not worn", st.gear_slots_used("helder") == 5 and st.owns_gear("helder", items[5].id) and not st.is_gear_equipped("helder", items[5].id))
	_check("equipment costs 50 each", st.fragments == 2000 - 6 * 50)
	_check("no stacking: can't buy twice", not st.buy_gear("helder", items[0]))
	_check("each character owns their own copy", not st.owns_gear("radik", items[0].id) and st.buy_gear("radik", items[0]))
	_check("can't equip with slots full", not st.equip_gear("helder", items[5].id))
	_check("unequip frees a slot", st.unequip_gear("helder", items[0].id) and st.equip_gear("helder", items[5].id))

	var st2 := GameState.new()
	st2.ensure_defaults()
	st2.fragments = 500
	st2.buy_gear("dean", GearLibrary.get_equipment("jamu_palapa"))
	st2.buy_gear("dean", GearLibrary.get_equipment("gatotkaca"))
	var dd = Roster.get_def("dean")
	var ds := st2.stats_for("dean")
	_check("Jamu + Gatotkaca stats", ds["health"] == dd.health - 20 + 10 and ds["capability"] == dd.capability + 20 and ds["attack"] == dd.attack + 10 and ds["speed"] == maxi(0, dd.speed + 5 - 5))

	var path := "user://smoke_test_save.json"
	st.learn_skill(SkillLibrary.get_skill("h_rejuvenate"))
	st.save(path)
	var loaded := GameState.load_or_new(path)
	_check("save round-trip: fragments, gear, skills", loaded.fragments == st.fragments and loaded.is_gear_equipped("helder", items[5].id) \
		and loaded.owns_gear("radik", items[0].id) and loaded.skills_learned.has("h_rejuvenate"))
	GameState.delete_save(path)
	var old_style := GameState.new()
	old_style._apply({"fragments": 40, "owned": ["helder_baton_2"], "equipped": {"helder": "helder_baton_2"}})
	old_style.ensure_defaults()
	_check("old saves (no gear/skills fields) still load", old_style.fragments == 40 and old_style.equipped_id("helder") == "helder_baton_2")

	var fresh := GameState.new()
	fresh.ensure_defaults()
	var t0 := UnitFactory.make_player_team(fresh)
	_check("base skills only at start: 3/3/3/6 moves", t0[0].alteration_moves.size() == 3 and t0[1].alteration_moves.size() == 3 \
		and t0[2].alteration_moves.size() == 3 and t0[3].alteration_moves.size() == 6)
	fresh.fragments = 75
	_check("learning costs 75", fresh.learn_skill(SkillLibrary.get_skill("h_flicking")) and fresh.fragments == 0)
	_check("learned skill appears in battle", _find_move(UnitFactory.make_player_team(fresh)[0], "Flicking") != null)
	_check("not enough fragments: can't learn", not fresh.learn_skill(SkillLibrary.get_skill("h_rejuvenate")))
	for t in t0:
		t.free()

func _test_skill_effects() -> void:
	var a := _arena()
	var bm: BattleManager = a["bm"]
	var h: BattleUnit = a["helder"]
	var r: BattleUnit = a["radik"]
	var dn: BattleUnit = a["dean"]
	var w: BattleUnit = a["wyg"]
	var f0: BattleUnit = a["foes"][0]
	var f1: BattleUnit = a["foes"][1]
	var both: Array = a["foes"]

	# --- Helder ---
	bm._resolve_move(h, _find_move(h, "Strengthen"), [h])
	_check("Strengthen = +ceil(Capability/4) Strength", h.get_attack() == h.stats.attack + Move.round_up(h.stats.capability / 4.0))
	_check("Strengthen is limited to 2 uses", _find_move(h, "Strengthen").max_uses_per_battle == 2)
	h.status_text()
	var atk := h.get_attack()
	bm._resolve_move(h, _find_move(h, "Condemn"), [f0])
	_check("Condemn = 20 + Strength", _lost(f0) == 20 + atk, str(_lost(f0)))
	var weak := UnitFactory.make_enemy("Weak", 30, 0, 0, 0, [] as Array[Move])
	root.add_child(weak)
	h.current_health = 50
	bm._resolve_move(h, _find_move(h, "Condemn"), [weak])
	_check("Condemn kill heals 10% max HP", not weak.is_alive() and h.current_health == 50 + Move.round_up(h.stats.max_health * 0.1), str(h.current_health))
	weak.queue_free()
	h.current_health = 1
	var l0 := _lost(f0); var l1 := _lost(f1)
	bm._resolve_move(h, _find_move(h, "Absorption"), both)
	var each := 10 + Move.round_up(atk / 5.0)
	_check("Absorption = 10 + Strength/5 to all", _lost(f0) - l0 == each and _lost(f1) - l1 == each)
	_check("Absorption heals 30% of damage", h.current_health == 1 + 2 * Move.round_up(each * 0.3), str(h.current_health))
	h.current_health = 1
	dn.current_health = 1
	bm._resolve_move(h, _find_move(h, "Rejuvenate"), [h, dn])
	var rej := Move.round_up(h.stats.capability / 2.0)
	_check("Rejuvenate heals all allies Capability/2", h.current_health == 1 + rej and dn.current_health == 1 + rej)
	l0 = _lost(f0)
	bm._resolve_move(h, _find_move(h, "Flicking"), [f0])
	_check("Flicking = Strength", _lost(f0) - l0 == atk)

	# --- Radik ---
	l0 = _lost(f0); l1 = _lost(f1)
	bm._resolve_move(r, _find_move(r, "Ravaging"), both)
	_check("Ravaging = Speed x 2 to all", _lost(f0) - l0 == r.stats.speed * 2 and _lost(f1) - l1 == r.stats.speed * 2)
	l0 = _lost(f0)
	bm._resolve_move(r, _find_move(r, "One-Two"), [f0])
	_check("One-Two = 10 + Capability/2, twice", _lost(f0) - l0 == 2 * (10 + Move.round_up(r.stats.capability / 2.0)))
	bm._resolve_move(r, _find_move(r, "Stance \"Heroik\""), [r])
	_check("Heroik: counts as guarding", r.is_guarding)
	r.current_energy = 0
	bm._grant_stored_energy(r)
	_check("Heroik: +3 Energy next turn (once)", r.current_energy == 3)
	bm._grant_stored_energy(r)
	_check("Heroik energy is used up", r.current_energy == 3)
	var spd := r.get_speed()
	bm._resolve_move(r, _find_move(r, "Stance \"Kilau\""), [r])
	_check("Kilau = +ceil(Capability/4) Speed", r.get_speed() == spd + Move.round_up(r.stats.capability / 4.0))
	var prey := UnitFactory.make_enemy("Prey", 40, 0, 0, 0, [] as Array[Move])
	root.add_child(prey)
	r.current_energy = 0
	bm._resolve_move(r, _find_move(r, "\"Berandalan\""), [prey])
	_check("Berandalan kill refunds 2 Energy", not prey.is_alive() and r.current_energy == 2, str(r.current_energy))
	l0 = _lost(f0)
	bm._resolve_move(r, _find_move(r, "\"Berandalan\""), [f0])
	_check("Berandalan = 20 + Speed x 3", _lost(f0) - l0 == 20 + r.get_speed() * 3 and r.current_energy == 2)
	prey.queue_free()

	# --- Dean ---
	l0 = _lost(f0)
	bm._resolve_move(dn, _find_move(dn, "Enchain"), [f0])
	_check("Enchain = Strength + Stun", _lost(f0) - l0 == dn.get_attack() and f0.has_status(StatusDefs.Kind.STUN))
	l0 = _lost(f0); l1 = _lost(f1)
	bm._resolve_move(dn, _find_move(dn, "Eruption"), both)
	var eru := 5 + Move.round_up(dn.stats.capability / 5.0)
	_check("Eruption = 5 + Capability/5 to all", _lost(f0) - l0 == eru and _lost(f1) - l1 == eru)
	f0.remove_status(StatusDefs.Kind.STUN)
	dn.current_health = 10
	bm._resolve_move(dn, _find_move(dn, "Encompass"), both)
	_check("Encompass: stuns all + heals Dean 15", f0.has_status(StatusDefs.Kind.STUN) and f1.has_status(StatusDefs.Kind.STUN) and dn.current_health == 25, str(dn.current_health))
	f0.remove_status(StatusDefs.Kind.STUN)
	f1.remove_status(StatusDefs.Kind.STUN)
	l0 = _lost(f0)
	bm._resolve_move(dn, _find_move(dn, "Onslaught"), [f0])
	_check("Onslaught = 10 + Strength/2, three times", _lost(f0) - l0 == 3 * (10 + Move.round_up(dn.get_attack() / 2.0)))
	dn.is_guarding = false
	bm._resolve_move(dn, _find_move(dn, "Overcome"), [f1])
	_check("Overcome: stun + guard", f1.has_status(StatusDefs.Kind.STUN) and dn.is_guarding)

	# --- WYG-01 ---
	var cap := w.stats.capability
	var expected := {2: Move.round_up(cap * 1.0), 3: Move.round_up(cap * 1.5), 4: 20 + Move.round_up(cap * 2.0), 5: 20 + Move.round_up(cap * 2.5)}
	for e in expected:
		l0 = _lost(f1)
		bm._resolve_move(w, _find_move(w, "Cannon (%d Energy)" % e), [f1])
		_check("Cannon at %d Energy = %d" % [e, expected[e]], _lost(f1) - l0 == expected[e], str(_lost(f1) - l0))
	dn.current_health = 1
	bm._resolve_move(w, _find_move(w, "Field Heal"), [dn])
	_check("Field Heal = 20% of target max HP", dn.current_health == 1 + Move.round_up(dn.stats.max_health * 0.2), str(dn.current_health))
	for u in a["team"]:
		u.current_energy = 0
	bm._resolve_move(w, _find_move(w, "Booster"), a["team"])
	_check("Booster: +1 Energy to everyone", a["team"].all(func(u): return u.current_energy == 1))
	var hurt := UnitFactory.make_enemy("Hurt", 100, 0, 0, 0, [] as Array[Move])
	var fine := UnitFactory.make_enemy("Fine", 100, 0, 0, 0, [] as Array[Move])
	root.add_child(hurt)
	root.add_child(fine)
	hurt.current_health = 40
	l0 = _lost(f0)
	bm._resolve_move(w, _find_move(w, "Javelin"), [hurt])
	bm._resolve_move(w, _find_move(w, "Javelin"), [fine])
	var jav := 15 + Move.round_up(cap / 3.0)
	_check("Javelin = 15 + Capability/3", 100 - fine.current_health == jav)
	_check("Javelin stuns target below 50% HP only", hurt.has_status(StatusDefs.Kind.STUN) and not fine.has_status(StatusDefs.Kind.STUN))
	hurt.queue_free()
	fine.queue_free()
	l0 = _lost(f0); l1 = _lost(f1)
	bm._resolve_move(w, _find_move(w, "Firecracker"), both)
	var fc := 15 + Move.round_up(cap / 10.0)
	_check("Firecracker = 15 + Capability/10, twice, to all", _lost(f0) - l0 == 2 * fc and _lost(f1) - l1 == 2 * fc)

	# Regression: Secure's on-hit self-heal (old demo move) must still work.
	var secure := Move.new()
	secure.type = Move.Type.ALTERATION
	secure.deals_damage = false
	secure.stun_turns = 1
	secure.self_heal_max_hp_per_cap = 1.0 / 125.0
	dn.current_health = 1
	bm._resolve_move(dn, secure, [f0])
	_check("Secure still self-heals on hit", dn.current_health > 1)
	_cleanup(a)

func _test_workshop_ui() -> void:
	var st := GameState.new()
	st.ensure_defaults()
	st.fragments = 500
	var hub := WorkshopScreen.new()
	root.add_child(hub)
	await process_frame
	hub.refresh(st)
	_check("Workshop hub starts on the two choices", hub._hub.visible and not hub._equipment.visible and not hub._prep.visible)
	hub._equipment_btn.pressed.emit()
	_check("Equipment choice opens the 3-tab screen", hub._equipment.visible and not hub._hub.visible)
	hub._equipment.back_pressed.emit()
	_check("Back returns to the hub", hub._hub.visible)
	hub._prep_btn.pressed.emit()
	_check("Preparation choice opens the item screen", hub._prep.visible)
	hub._prep.back_pressed.emit()

	var ws: EquipmentWorkshop = hub._equipment
	ws._mode = EquipmentWorkshop.Mode.UPGRADES
	ws._rebuild()
	_check("Upgrades tab lists 3 rows", ws._list.get_child_count() == 3)
	ws._mode = EquipmentWorkshop.Mode.EQUIPMENT
	ws._rebuild()
	_check("Equipment tab lists 9 rows", ws._list.get_child_count() == 9)
	ws._mode = EquipmentWorkshop.Mode.SKILLS
	ws._rebuild()
	_check("Skill tab lists Helder's 5 skills", ws._list.get_child_count() == 5)
	for id in ["radik", "dean", "wyg01"]:
		ws._selected_id = id
		ws._rebuild()
		_check("Skill tab lists 5 skills for %s" % id, ws._list.get_child_count() == 5)
	ws._selected_id = "helder"
	ws._on_learn_skill(SkillLibrary.get_skill("h_rejuvenate"))
	_check("Learning from the UI spends 75", st.fragments == 425 and st.skills_learned.has("h_rejuvenate"))
	ws._mode = EquipmentWorkshop.Mode.EQUIPMENT
	ws._on_craft_gear(GearLibrary.get_equipment("keotop"))
	_check("Crafting from the UI spends 50 and wears it", st.fragments == 375 and st.is_gear_equipped("helder", "keotop"))

	var prep: PreparationWorkshop = hub._prep
	prep.refresh(st)
	var item_rows := 0
	for c in prep._list.get_children():
		if c is PanelContainer:
			item_rows += 1
	_check("Preparation lists 8 items in 4 categories", item_rows == 8 and prep._list.get_child_count() == 12, "%d rows, %d children" % [item_rows, prep._list.get_child_count()])
	var before := st.fragments
	prep._on_craft(ItemLibrary.get_item("med_njus"))
	_check("Crafting an item from the UI spends its price (5) and adds one", st.fragments == before - 5 and st.item_count("med_njus") == 1)
	hub.queue_free()

func _test_items() -> void:
	var prices := {"meg_p3k": 20, "meg_r3v": 35, "med_njus": 5, "evvac_emk": 15, "kratingden": 25, "bir_pletok": 55, "inj_cqb": 50, "inj_acb": 50}
	for id in prices:
		var it := ItemLibrary.get_item(id)
		_check("item %s costs %d" % [id, prices[id]], it != null and it.cost == prices[id])
	var st := GameState.new()
	st.ensure_defaults()
	st.fragments = 100
	for i in ItemLibrary.MAX_STACK:
		st.inventory["med_njus"] = st.item_count("med_njus") + 1
	_check("can't carry more than %d of one item" % ItemLibrary.MAX_STACK, not st.buy_item(ItemLibrary.get_item("med_njus")))
	_check("can't craft without enough Fragments", not GameState.new().buy_item(ItemLibrary.get_item("inj_cqb")))
	st.inventory["evvac_emk"] = 2
	var path := "user://smoke_test_save2.json"
	st.save(path)
	_check("inventory survives save/load", GameState.load_or_new(path).item_count("evvac_emk") == 2)
	GameState.delete_save(path)

	var a := _arena(1)
	var bm: BattleManager = a["bm"]
	var h: BattleUnit = a["helder"]
	var r: BattleUnit = a["radik"]
	var K := StatusDefs.Kind
	bm.add_item(ItemLibrary.get_item("med_njus"), 1)
	bm.add_item(ItemLibrary.get_item("evvac_emk"), 1)
	bm.add_item(ItemLibrary.get_item("meg_p3k"), 1)
	bm.add_item(ItemLibrary.get_item("meg_r3v"), 1)
	bm.add_item(ItemLibrary.get_item("kratingden"), 1)
	bm.add_item(ItemLibrary.get_item("bir_pletok"), 1)
	bm.add_item(ItemLibrary.get_item("inj_cqb"), 1)
	bm.add_item(ItemLibrary.get_item("inj_acb"), 1)

	h.current_health = 1
	bm._resolve_item(r, ItemLibrary.get_item("med_njus"), [h])
	_check("Med-Njus heals 20% of max HP", h.current_health == 1 + Move.round_up(h.stats.max_health * 0.2), str(h.current_health))
	h.current_health = 1
	bm._resolve_item(r, ItemLibrary.get_item("evvac_emk"), [h])
	_check("EVVAC-EMK heals 40% of max HP", h.current_health == 1 + Move.round_up(h.stats.max_health * 0.4))
	h.current_health = 0
	h.defeated.emit(h) # (KO'd)
	bm._resolve_item(r, ItemLibrary.get_item("meg_p3k"), [h])
	_check("M.E.G-P3K revives a downed ally at 15% HP", h.current_health == Move.round_up(h.stats.max_health * 0.15), str(h.current_health))
	h.current_health = 0
	bm._resolve_item(r, ItemLibrary.get_item("meg_r3v"), [h])
	_check("M.E.G-R3V revives at 30% HP", h.current_health == Move.round_up(h.stats.max_health * 0.3))
	h.current_health = 1
	h.current_energy = 0
	bm._resolve_item(r, ItemLibrary.get_item("kratingden"), [h])
	_check("Kratingden: +10% HP and +2 Energy", h.current_health == 1 + Move.round_up(h.stats.max_health * 0.1) and h.current_energy == 2)
	h.current_energy = 0
	bm._resolve_item(r, ItemLibrary.get_item("bir_pletok"), [h])
	_check("Bir Pletok: +4 Energy", h.current_energy == 4)
	_check("item stock is spent", bm.party_inventory[ItemLibrary.get_item("med_njus")] == 0)

	# Admin's injections: buffs for 3 turns, then a 10% crash (never lethal).
	var spd := r.get_speed()
	var atk := r.get_attack()
	bm._resolve_item(h, ItemLibrary.get_item("inj_cqb"), [r])
	_check("Inj-CQB: +5 Speed, +10 Strength", r.get_speed() == spd + 5 and r.get_attack() == atk + 10)
	var cap := r.get_capability()
	bm._resolve_item(h, ItemLibrary.get_item("inj_acb"), [r])
	_check("Inj-ACB: +15 Capability", r.get_capability() == cap + 15)
	r.current_health = r.stats.max_health
	for i in 2:
		r.tick_end_of_turn()
	_check("injections still active after 2 turns", r.has_status(K.INJ_CQB) and r.has_status(K.INJ_ACB))
	r.tick_end_of_turn()
	_check("injections wear off after 3 turns", not r.has_status(K.INJ_CQB) and not r.has_status(K.INJ_ACB))
	_check("both crashes hit: 2 x 10% max HP", r.current_health == r.stats.max_health - 2 * Move.round_up(r.stats.max_health * 0.1), str(r.current_health))
	_check("buffs are gone again", r.get_speed() == spd and r.get_attack() == atk and r.get_capability() == cap)
	r.current_health = 3
	r.add_status(K.INJ_CQB)
	for i in 3:
		r.tick_end_of_turn()
	_check("the crash never kills (leaves 1 HP)", r.is_alive() and r.current_health == 1, str(r.current_health))
	# Buffed Capability feeds skills (Inj-ACB + Cannon).
	var w: BattleUnit = a["wyg"]
	var foe: BattleUnit = a["foes"][0]
	var base_hit := _find_move(w, "Cannon (2 Energy)").damage_per_hit(w.get_attack(), w.get_capability(), w.get_speed())
	w.add_status(K.INJ_ACB)
	var boosted := _find_move(w, "Cannon (2 Energy)").damage_per_hit(w.get_attack(), w.get_capability(), w.get_speed())
	_check("Inj-ACB raises Capability-scaled damage", boosted > base_hit)
	_check("status_lines lists statuses with turns left", w.status_lines().size() == 1 and w.status_lines()[0].contains("Inj-ACB") and w.status_lines()[0].contains("3 turns"), str(w.status_lines()))
	_cleanup(a)

func _test_battle_ui() -> void:
	var ms := MissionLibrary.build_all()
	var st := _state_all_skills()
	var bm := BattleManager.new()
	bm.crit_chance = 0.0
	var team := UnitFactory.make_player_team(st)
	var foes: Array[BattleUnit] = []
	foes.assign(ms[1].build_wave(0)) # mission 2 wave 1: 3 Sloppy + 1 Tough
	bm.player_team = team
	bm.enemy_team = foes
	bm.wave_count = ms[1].wave_count()
	bm.wave_factory = func(i): return ms[1].build_wave(i)
	var holder := Node.new()
	root.add_child(holder)
	holder.add_child(bm)
	for u in team + foes:
		holder.add_child(u)
	var ui := BattleUI.new()
	ui.battle_manager = bm
	holder.add_child(ui)
	var stage := BattleStage.new()
	stage.battle_manager = bm
	holder.add_child(stage)
	var seen := {"markers": 0}
	ui.target_focused.connect(func(units): seen["markers"] += units.size())
	await create_timer(0.3).timeout

	_check("UI: Wave panel shows 1/3", ui._wave_value.text == "1/3")
	_check("UI: party bar has 4 cells, enemy list 4 rows", ui._party_cells.size() == 4 and ui._enemy_cells.size() == 4)
	_check("UI: 'Helder's turn' sits above Helder's cell", ui._party_cells[team[0]]["turn_label"].text == "Helder's turn" and ui._party_cells[team[1]]["turn_label"].text == "")
	_check("UI: Status tab is hidden while a unit has no status", not ui._party_cells[team[0]]["tab"].visible)
	team[1].add_status(StatusDefs.Kind.GLOOP, 3)
	team[1].add_status(StatusDefs.Kind.POISON, 1)
	await process_frame
	_check("UI: Status tab appears for an afflicted ally", ui._party_cells[team[1]]["tab"].visible)
	_check("UI: the Status list has one line per status", ui._party_cells[team[1]]["popup_lines"].get_child_count() == 2)
	_check("UI: Attack list shows Helder's basic move", ui._move_list.get_child_count() == 1 and ui._move_list.get_child(0).text == "Drabo")

	team[0].current_energy = 5
	ui._on_player_turn(team[0], bm.get_available_actions(team[0]))
	ui._on_category_pressed("alteration")
	_check("UI: Alteration list shows all 5 of Helder's skills", ui._move_list.get_child_count() == 5)
	for b in ui._move_list.get_children():
		if b.text.begins_with("Condemn"):
			b.pressed.emit()
	await process_frame
	_check("UI: single-target move shows 4 enemy buttons in a 2-column grid", ui._target_grid.get_child_count() == 4 and ui._target_grid.columns == 2)
	_check("UI: Target menu shows a marker over the first enemy", seen["markers"] >= 1)
	_check("UI: Esc backs out of target selection", ui._on_cancel.is_valid())
	ui._on_cancel.call()
	await process_frame
	_check("UI: target panel is empty after backing out", ui._target_grid.get_child_count() == 0)

	var before := foes[0].current_health
	ui._on_category_pressed("alteration")
	for b in ui._move_list.get_children():
		if b.text.begins_with("Condemn"):
			b.pressed.emit()
	await process_frame
	ui._target_grid.get_child(0).pressed.emit()
	await create_timer(0.4).timeout
	_check("UI: choosing a target runs the action", foes[0].current_health < before)
	_check("UI: 'name used' strip shows the action", ui._name_used.text.contains("Condemn"), ui._name_used.text)
	holder.queue_free()
	await process_frame

func _test_title_and_flow() -> void:
	var path := "user://smoke_test_title.json"
	GameState.delete_save(path)
	var fresh := GameState.load_or_new(path)
	_check("no save file yet", not GameState.save_exists(path) and fresh.save_path == path)

	var title := TitleScreen.new()
	title.total_missions = 13
	root.add_child(title)
	await process_frame
	title.refresh(fresh)
	_check("Title: Continue is disabled without a save", title._continue_btn.disabled)
	var got := {"new": 0, "cont": 0}
	title.new_game_pressed.connect(func(): got["new"] += 1)
	title.continue_pressed.connect(func(): got["cont"] += 1)
	title._new_btn.pressed.emit()
	_check("Title: New Game with no save starts without asking", got["new"] == 1 and not title._confirm.visible)

	fresh.fragments = 77
	fresh.mark_cleared(&"permulaan_baru")
	fresh.seen_lobby_intro = true # (otherwise the lobby intro waits for a click)
	fresh.save()
	title.refresh(fresh)
	_check("Title: Continue is enabled and shows a summary", not title._continue_btn.disabled and title._summary.text.contains("77") and title._summary.text.contains("1 / 13"), title._summary.text)
	title._new_btn.pressed.emit()
	_check("Title: New Game with a save asks first, Cancel is focused", title._confirm.visible and got["new"] == 1)
	title._confirm_no.pressed.emit()
	_check("Title: Cancel closes the question and starts nothing", not title._confirm.visible and got["new"] == 1)
	title._continue_btn.pressed.emit()
	_check("Title: Continue emits", got["cont"] == 1)
	title.queue_free()

	# The real flow: starts on the title; Continue -> lobby; New Game wipes the save.
	var flow := Node.new()
	flow.set_script(load("res://scripts/main/game_flow.gd"))
	flow.save_path = path
	root.add_child(flow)
	await process_frame
	_check("Flow starts on the title screen", flow._title.visible and not flow._lobby.visible)
	flow._on_continue()
	await create_timer(0.8).timeout
	_check("Continue leads to the lobby with saved progress", flow._lobby.visible and flow._lobby._fragments_label.text.contains("77"), flow._lobby._fragments_label.text)
	flow._lobby.title_pressed.emit()
	await create_timer(0.8).timeout
	_check("Lobby > Main Menu returns to the title", flow._title.visible)
	flow.queue_free()
	await process_frame

	var flow2 := Node.new()
	flow2.set_script(load("res://scripts/main/game_flow.gd"))
	flow2.save_path = path
	root.add_child(flow2)
	await process_frame
	flow2._on_new_game()
	await create_timer(0.8).timeout
	_check("New Game wipes progress and writes a fresh save", flow2._state.fragments == 0 and flow2._state.cleared.is_empty() and GameState.save_exists(path))
	_check("New Game starts mission 1 immediately", flow2._busy and not flow2._title.visible and not flow2._lobby.visible)
	flow2.queue_free()
	await process_frame
	GameState.delete_save(path)

func _test_training() -> void:
	# Energy is always full, nothing costs energy, Sapped can't lock a skill.
	var u := _unit()
	u.infinite_energy = true
	u.current_energy = 5
	var big := Move.new()
	big.type = Move.Type.ALTERATION
	big.energy_cost = 5
	u.add_status(StatusDefs.Kind.SAPPED) # 6 energy needed normally
	_check("Training: any skill is usable even when Sapped", u.can_use_move(big))
	_check("Training: spending energy keeps the bar full", u.spend_energy(5) and u.current_energy == BattleUnit.MAX_ENERGY)
	u.current_energy = 0
	u.gain_energy(1)
	_check("Training: energy refills", u.current_energy == BattleUnit.MAX_ENERGY)

	var dummy := load("res://data/enemies/training_dummy.tres") as EnemyType
	var d := dummy.build_unit()
	_check("Training dummy: huge HP, never acts", d.stats.max_health == 99999 and d.is_dummy)

	# A short training battle: dummies never attack, abort ends it cleanly.
	var bm := BattleManager.new()
	bm.crit_chance = 0.0
	bm.training = true
	var team := UnitFactory.make_player_team(_state_all_skills())
	var foes: Array[BattleUnit] = []
	for i in 2:
		foes.append(dummy.build_unit())
	bm.player_team = team
	bm.enemy_team = foes
	var holder := Node.new()
	root.add_child(holder)
	holder.add_child(bm)
	for x in team + foes:
		holder.add_child(x)
	await process_frame
	var state := {"ended": false, "won": false, "rounds": 0, "dummy_turns": 0}
	bm.battle_ended.connect(func(w): state["ended"] = true; state["won"] = w)
	bm.round_started.connect(func(n): state["rounds"] = n)
	bm.enemy_turn_started.connect(func(_u): state["dummy_turns"] += 1)
	var turns := [0]
	bm.player_turn_started.connect(func(unit, actions):
		turns[0] += 1
		if turns[0] <= 20: # (a few rounds, then the "player" goes idle)
			bm.submit_player_action.call_deferred({"type": "guard", "targets": []})
	)
	bm.start_battle()
	await _await_frames(30)
	_check("Training: party starts with a full energy bar", team.all(func(t): return t.current_energy == BattleUnit.MAX_ENERGY and t.infinite_energy))
	_check("Training: the battle keeps going round after round", state["rounds"] >= 3 and not state["ended"], str(state))
	_check("Training: dummies never take a turn", state["dummy_turns"] == 0 and foes.all(func(f): return f.current_health == 99999))
	bm.abort_battle()
	_check("Training: aborting ends the battle as a normal finish", state["ended"] and state["won"])
	holder.queue_free()
	await process_frame

	# The real flow: lobby > Training > leave. Nothing is rewarded or spent.
	var path := "user://smoke_test_training.json"
	GameState.delete_save(path)
	var st := GameState.load_or_new(path)
	st.fragments = 123
	st.seen_lobby_intro = true
	st.inventory["med_njus"] = 2
	st.save()
	var flow := Node.new()
	flow.set_script(load("res://scripts/main/game_flow.gd"))
	flow.save_path = path
	root.add_child(flow)
	await process_frame
	flow._on_continue()
	await create_timer(0.8).timeout
	flow._on_training_pressed()
	await create_timer(1.6).timeout
	_check("Flow: Training builds a battle with 2 dummies", flow._battle_root != null)
	var fbm: BattleManager = flow._battle_root.get_node("BattleManager")
	_check("Flow: it is a training battle with two dummies", fbm.training and fbm.enemy_team.size() == 2 and fbm.enemy_team[0].stats.character_name == "Training Dummy A")
	fbm.party_inventory[ItemLibrary.get_item("med_njus")] = 0 # pretend both were used
	fbm.abort_battle()
	await create_timer(3.6).timeout
	_check("Flow: leaving Training returns to the lobby", flow._lobby.visible and not flow._busy)
	_check("Flow: no reward and no item spent", flow._state.fragments == 123 and flow._state.item_count("med_njus") == 2)
	flow.queue_free()
	await process_frame
	GameState.delete_save(path)

func _test_misc_requests() -> void:
	# Guard grants an Energized +1 effect (arrives at the start of the next turn).
	var a := _arena(1)
	var bm: BattleManager = a["bm"]
	var h: BattleUnit = a["helder"]
	h.current_energy = 0
	bm._execute_action(h, {"type": "guard", "targets": []})
	_check("Guard: guarding stance + Energized +1", h.is_guarding and h.magnitude_of(StatusDefs.Kind.ENERGIZED) == 1)
	_check("Guard: no instant energy", h.current_energy == 0)
	bm._grant_stored_energy(h)
	_check("Guard: +1 Energy at the start of the next turn", h.current_energy == 1)

	# Dodge indicator: fires for every attack, damaging or not; no status on a dodge.
	var foe: BattleUnit = a["foes"][0]
	foe.force_dodge = true
	var seen := {"dodges": 0}
	bm.attack_dodged.connect(func(_t, _a2): seen["dodges"] += 1)
	var zero := Move.new()
	zero.deals_damage = false
	zero.stun_turns = 1
	bm._resolve_move(h, zero, [foe])
	_check("Dodge signal fires for a 0-damage attack", seen["dodges"] == 1)
	_check("A dodged status attack inflicts nothing", not foe.has_status(StatusDefs.Kind.STUN))
	var strike := Move.new()
	bm._resolve_move(h, strike, [foe])
	_check("Dodge signal fires for a damaging attack", seen["dodges"] == 2 and foe.current_health == foe.stats.max_health)
	var clockwatch := Move.new()
	clockwatch.deals_damage = false
	clockwatch.stun_turns = 1
	clockwatch.effects_ignore_dodge = true
	bm._resolve_move(h, clockwatch, [foe])
	_check("Clockwatch-style moves still stun through a dodge", foe.has_status(StatusDefs.Kind.STUN) and seen["dodges"] == 3)
	_cleanup(a)

	# Party limits and the stage layout for a small party.
	var st := GameState.new()
	st.ensure_defaults()
	var duo := UnitFactory.make_player_team(st, PackedStringArray(["helder", "radik"]))
	_check("A mission can limit the party to Helder + Radik", duo.size() == 2 and duo[0].stats.character_name == "Helder" and duo[1].stats.character_name == "Radik")
	_check("No limit = the whole party", UnitFactory.make_player_team(st).size() == 4)
	for u in duo:
		u.free()

	# Tutorial text format.
	var pages := TutorialPage.load_file("res://data/missions/01_permulaan_baru/tutorial.txt")
	_check("Tutorial file parses into 2 pages", pages.size() == 2, str(pages.size()))
	_check("Tutorial page 1: Attack/Alteration/Item/Guard badges + controls", pages[0].rows.size() == 7 and pages[0].rows[0][0] == "Attack" and pages[0].rows[3][0] == "Guard")
	_check("Tutorial page 2: the two battle paragraphs", pages[1].paragraphs.size() == 2 and pages[1].paragraphs[1].begins_with("Alteration adalah"))
	var tiny := TutorialPage.parse("A\n> X | y\ntext\n---\nB\nmore\n---\n")
	_check("Tutorial parser: titles, rows, paragraphs, trailing separator", tiny.size() == 2 and tiny[0].title == "A" and tiny[0].rows == [["X", "y"]] and tiny[0].paragraphs == PackedStringArray(["text"]) and tiny[1].paragraphs.size() == 1)

	# Title card background placeholder.
	var fader := ScreenFader.new()
	root.add_child(fader)
	_check("Title card has a placeholder background", fader._placeholder_bg != null and fader._card_bg != null)
	fader.queue_free()

func _test_tutorial_box() -> void:
	var box := TutorialBox.new()
	root.add_child(box)
	await process_frame
	var pages := TutorialPage.load_file("res://data/missions/01_permulaan_baru/tutorial.txt")
	var done := {"v": false}
	box.finished.connect(func(): done["v"] = true)
	box.play(pages)
	await process_frame
	_check("Tutorial box opens on page 1", box.visible and box._counter.text == "1 / 2" and not box._back_btn.visible)
	box._next_btn.pressed.emit()
	await process_frame
	_check("Next shows page 2 with 'Mulai'", box._counter.text == "2 / 2" and box._next_btn.text == "Mulai" and box._back_btn.visible)
	box._back_btn.pressed.emit()
	await process_frame
	_check("Back returns to page 1", box._counter.text == "1 / 2")
	box._next_btn.pressed.emit()
	box._next_btn.pressed.emit()
	await process_frame
	_check("Finishing closes the box", done["v"] and not box.visible)
	box.queue_free()

func _test_tutorial_in_flow() -> void:
	var path := "user://smoke_test_tut.json"
	GameState.delete_save(path)
	var flow := Node.new()
	flow.set_script(load("res://scripts/main/game_flow.gd"))
	flow.save_path = path
	root.add_child(flow)
	await process_frame
	var m: Mission = flow._missions[0]
	flow._run_battle(m)
	await create_timer(1.2).timeout
	var bm: BattleManager = flow._battle_root.get_node("BattleManager")
	_check("Flow: mission 1 battle has only Helder + Radik", bm.player_team.size() == 2)
	_check("Flow: the tutorial shows before the battle starts", flow._tutorial.visible and bm._round_number == 0)
	flow._tutorial.finished.emit()
	await create_timer(0.4).timeout
	_check("Flow: closing the tutorial starts the battle", not flow._tutorial.visible and bm._round_number == 1)
	flow.queue_free()
	await process_frame
	GameState.delete_save(path)
