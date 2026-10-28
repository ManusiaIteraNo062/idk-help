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
		for l in m.intro_lines + m.victory_lines:
			if l.text.length() > DialogueParser.MAX_CHARS + 120:
				_check("%s line length" % m.id, false, str(l.text.length()))
	_check("mission ids unique", seen.size() == ms.size())
	_check("mission 13 is story-only", ms[12].wave_count() == 0)
	var expected_waves := [2, 3, 1, 3, 3, 3, 3, 1, 3, 3, 3, 1]
	for i in 12:
		_check("mission %d has %d waves" % [i + 1, expected_waves[i]], ms[i].wave_count() == expected_waves[i], str(ms[i].wave_count()))
	_check("m1 wave1 = 4 enemies, named A-D", ms[0].build_wave(0).size() == 4 and ms[0].build_wave(0)[3].stats.character_name == "Sloppy Altered D")
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
	_check("gloop +1 per stack", u.take_damage(10) == 13)
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
