extends Node
## Attach this to your main scene's root Node. It builds a sample battle
## entirely from code (no .tres resources needed to try it out) and starts
## it immediately. Replace _build_player_team()/_build_enemy_team() with
## your real party/encounter data once you're happy with the system.

func _ready() -> void:
	var battle_manager := BattleManager.new()
	battle_manager.name = "BattleManager"
	battle_manager.player_team = _build_player_team()
	battle_manager.enemy_team = _build_enemy_team()

	var potion := Item.new()
	potion.item_name = "Potion"
	potion.heal_amount = 40
	potion.description = "Restores 40 HP."
	battle_manager.add_item(potion, 3)

	var phoenix_down := Item.new()
	phoenix_down.item_name = "Phoenix Down"
	phoenix_down.heal_amount = 0
	phoenix_down.revive = true
	phoenix_down.description = "Revives a fallen ally at 50% HP."
	battle_manager.add_item(phoenix_down, 1)

	add_child(battle_manager)
	for unit in battle_manager.player_team + battle_manager.enemy_team:
		add_child(unit)

	var ui := preload("res://scripts/ui/battle_ui.gd").new()
	ui.battle_manager = battle_manager
	add_child(ui)

	var stage := preload("res://scripts/ui/battle_stage.gd").new()
	stage.battle_manager = battle_manager
	stage.position = Vector2(600, 220) # nudged up to clear the bottom UI bands
	add_child(stage)

# ---------------------------------------------------------------------------
# PLAYER TEAM
# ---------------------------------------------------------------------------

func _build_player_team() -> Array[BattleUnit]:
	var team: Array[BattleUnit] = []
	# _make_unit(name, health, attack, capability, speed/dodge%, basic_move_name)
	team.append(_make_unit("Helder", 100, 16, 4, 9, "Drabo"))          # Warrior / fighter
	team.append(_make_unit("Radik", 90, 8, 12, 15, "Aparang"))          # Rogue / ranger
	team.append(_make_unit("Dean", 120, 5, 10, 7, "Law & Order"))       # Tank / debuffer
	team.append(_make_unit("Admin", 100, 3, 18, 5, "Mech Fist"))        # Artificer

	# Alterations (energy costs marked PLACEHOLDER are my picks, easy to change).
	_add_helder_alterations(team[0])
	_add_radik_alterations(team[1])
	_add_dean_alterations(team[2])
	_add_admin_alterations(team[3])

	return team

## Helder - "Oxypetalum"
func _add_helder_alterations(unit: BattleUnit) -> void:
	var strengthen := Move.new()
	strengthen.move_name = "Oxypetalum - Strengthen"
	strengthen.type = Move.Type.ALTERATION
	strengthen.target_type = Move.Target.SELF
	strengthen.energy_cost = 2           # PLACEHOLDER (accepted for now)
	strengthen.buff_attack_flat = 5      # gain = 5 + Capability
	strengthen.buff_attack_cap_mult = 1.0
	strengthen.max_uses_per_battle = 2
	unit.alteration_moves.append(strengthen)

	var condemn := Move.new()
	condemn.move_name = "Oxypetalum - Condemn"
	condemn.type = Move.Type.ALTERATION
	condemn.target_type = Move.Target.SINGLE_ENEMY
	condemn.energy_cost = 5              # PLACEHOLDER (accepted for now)
	condemn.power = 0
	condemn.scaling_mult = 20.0          # damage = Capability * 20
	condemn.execute_base = 50            # KO if HP < 50 + (Capability / 2) * 15
	condemn.execute_per_cap = 7.5
	unit.alteration_moves.append(condemn)

	var absorption := Move.new()
	absorption.move_name = "Oxypetalum - Absorption"
	absorption.type = Move.Type.ALTERATION
	absorption.target_type = Move.Target.SINGLE_ENEMY
	absorption.energy_cost = 3           # PLACEHOLDER (accepted for now)
	absorption.power = 0
	absorption.scaling_mult = 5.0        # damage = Capability * 5
	absorption.lifesteal = 1.0           # heals the damage dealt
	unit.alteration_moves.append(absorption)

## Radik - "Palesa"
func _add_radik_alterations(unit: BattleUnit) -> void:
	var stylish := Move.new()
	stylish.move_name = "Palesa - Stylish"
	stylish.type = Move.Type.ALTERATION
	stylish.target_type = Move.Target.SINGLE_ENEMY
	stylish.energy_cost = 3              # PLACEHOLDER
	stylish.power = 0
	stylish.scaling_mult = 1.0           # damage = Capability + Speed
	stylish.speed_mult = 1.0
	unit.alteration_moves.append(stylish)

	var heroic := Move.new()
	heroic.move_name = "Palesa - Heroic"
	heroic.type = Move.Type.ALTERATION
	heroic.target_type = Move.Target.ALL_ENEMIES
	heroic.energy_cost = 5               # PLACEHOLDER
	heroic.power = 20                    # damage = Capability + 20, hits twice
	heroic.scaling_mult = 1.0
	heroic.hits = 2
	unit.alteration_moves.append(heroic)

	var backhand := Move.new()
	backhand.move_name = "Palesa - Backhand"
	backhand.type = Move.Type.ALTERATION
	backhand.target_type = Move.Target.SINGLE_ENEMY
	backhand.energy_cost = 2             # PLACEHOLDER
	backhand.power = 0
	backhand.scaling_mult = 1.0          # damage = Capability, then stun 1 turn
	backhand.stun_turns = 1
	unit.alteration_moves.append(backhand)

## Dean - "Taksaka"
func _add_dean_alterations(unit: BattleUnit) -> void:
	var secure := Move.new()
	secure.move_name = "Taksaka - Secure"
	secure.type = Move.Type.ALTERATION
	secure.target_type = Move.Target.SINGLE_ENEMY
	secure.energy_cost = 2                  # PLACEHOLDER
	secure.deals_damage = false             # no damage: stun + self-heal only
	secure.stun_turns = 1
	secure.self_heal_max_hp_per_cap = 1.0 / 125.0   # heals Capability/125 of max HP
	unit.alteration_moves.append(secure)

	var ravage := Move.new()
	ravage.move_name = "Taksaka - Ravage"
	ravage.type = Move.Type.ALTERATION
	ravage.target_type = Move.Target.ALL_ENEMIES
	ravage.energy_cost = 4                  # PLACEHOLDER
	ravage.power = 50                       # damage = 50 + Capability / 2
	ravage.scaling_mult = 0.5
	unit.alteration_moves.append(ravage)

	var intimidate := Move.new()
	intimidate.move_name = "Taksaka - Intimidate"
	intimidate.type = Move.Type.ALTERATION
	intimidate.target_type = Move.Target.SINGLE_ENEMY
	intimidate.energy_cost = 5              # PLACEHOLDER
	intimidate.power = 80                   # damage = 80 + Capability
	intimidate.scaling_mult = 1.0
	unit.alteration_moves.append(intimidate)

## Admin - "Synthetica" (his creation, WYG-01, does the fighting)
func _add_admin_alterations(unit: BattleUnit) -> void:
	var swords := Move.new()
	swords.move_name = "WYG-01 // Swords"
	swords.type = Move.Type.ALTERATION
	swords.target_type = Move.Target.SINGLE_ENEMY
	swords.energy_cost = 5                  # PLACEHOLDER
	swords.power = 30                       # each sword = 30 + Capability / 10
	swords.scaling_mult = 0.1
	swords.hits = 5
	unit.alteration_moves.append(swords)

	# Cannon is two menu entries so the player picks 3 or 5 energy.
	var cannon := Move.new()
	cannon.move_name = "WYG-01 // Cannon"
	cannon.type = Move.Type.ALTERATION
	cannon.target_type = Move.Target.SINGLE_ENEMY
	cannon.energy_cost = 3
	cannon.power = 0                        # damage = 2 x Capability
	cannon.scaling_mult = 2.0
	unit.alteration_moves.append(cannon)

	var cannon_double := Move.new()
	cannon_double.move_name = "WYG-01 // Cannon (Double Shot)"
	cannon_double.type = Move.Type.ALTERATION
	cannon_double.target_type = Move.Target.SINGLE_ENEMY
	cannon_double.energy_cost = 5
	cannon_double.power = 0
	cannon_double.scaling_mult = 2.0
	cannon_double.hits = 2                  # fires twice at 5 energy
	unit.alteration_moves.append(cannon_double)

	var supplication := Move.new()
	supplication.move_name = "WYG-01 // Supplication"
	supplication.type = Move.Type.ALTERATION
	supplication.target_type = Move.Target.SINGLE_ALLY
	supplication.energy_cost = 1
	supplication.is_heal = true
	supplication.power = 0
	supplication.heal_pct_base = 10.0       # heals 10% + Capability / 2 % of max HP
	supplication.heal_pct_per_cap = 0.5
	unit.alteration_moves.append(supplication)

# ---------------------------------------------------------------------------
# ENEMY TEAM (unchanged)
# ---------------------------------------------------------------------------

func _build_enemy_team() -> Array[BattleUnit]:
	var team: Array[BattleUnit] = []

	# Grunt: a single fixed move, used every single turn, no exceptions.
	# Claw Swipe is BASIC (physical) - it scales off the Grunt's Attack.
	var grunt := _make_unit("Brutish Altered", 200, 12, 2, 5)
	grunt.basic_moves.clear() # enemies with a moveset don't need basic_moves at all
	grunt.moveset = _make_moveset([
		_make_enemy_move("Claw Swipe", 8, Move.Target.SINGLE_ENEMY, Move.Type.BASIC),
	])
	team.append(grunt)

	# Shaman: fixed 3-step pattern that repeats forever - bolt, bolt, then
	# a party-wide hex. Fully deterministic, no RNG, no energy bar, no
	# Basic/Alteration menu. Its moves are ALTERATION (magic) - they scale
	# off the Shaman's Capability instead of Attack.
	var shaman := _make_unit("Aggressive Altered", 150, 3, 13, 7)
	shaman.basic_moves.clear()
	shaman.moveset = _make_moveset([
		_make_enemy_move("Hex Bolt", 10, Move.Target.SINGLE_ENEMY, Move.Type.ALTERATION),
		_make_enemy_move("Hex Bolt", 10, Move.Target.SINGLE_ENEMY, Move.Type.ALTERATION),
		_make_enemy_move("Rite of Ruin", 6, Move.Target.ALL_ENEMIES, Move.Type.ALTERATION),
	])
	team.append(shaman)

	return team

# ---------------------------------------------------------------------------
# HELPERS
# ---------------------------------------------------------------------------

func _make_moveset(moves: Array[Move]) -> EnemyMoveset:
	var ms := EnemyMoveset.new()
	ms.moves = moves
	return ms

## type here just means "physical (BASIC) or magical (ALTERATION)" for
## damage scaling - it has nothing to do with energy for enemies.
func _make_enemy_move(move_name: String, power: int, target: Move.Target, type: Move.Type = Move.Type.BASIC) -> Move:
	var move := Move.new()
	move.move_name = move_name
	move.power = power
	move.target_type = target
	move.type = type
	return move

func _make_unit(unit_name: String, health: int, attack: int, capability: int, speed: int, basic_name: String = "Strike") -> BattleUnit:
	var stats := CharacterStats.new()
	stats.character_name = unit_name
	stats.max_health = health
	stats.attack = attack
	stats.capability = capability
	stats.speed = speed

	var unit := BattleUnit.new()
	unit.name = unit_name
	unit.stats = stats

	var strike := Move.new()
	strike.move_name = basic_name
	strike.type = Move.Type.BASIC
	strike.power = 6
	strike.target_type = Move.Target.SINGLE_ENEMY
	unit.basic_moves.append(strike)

	return unit

func _add_alteration(unit: BattleUnit, move_name: String, cost: int, power: int, target: Move.Target) -> void:
	var move := Move.new()
	move.move_name = move_name
	move.type = Move.Type.ALTERATION
	move.energy_cost = cost
	move.power = power
	move.target_type = target
	unit.alteration_moves.append(move)
