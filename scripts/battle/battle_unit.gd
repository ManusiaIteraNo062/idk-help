extends Node
class_name BattleUnit
## A single combatant (player character OR enemy) in the battle.
##
## CharacterStats holds only the 4 fixed base numbers (health/attack/
## capability/speed). Everything that changes DURING a fight - current HP,
## current energy, whether it's guarding, buffs, stun - lives here on the
## unit instead, since that's runtime state, not a stat. Each unit owns its
## own CharacterStats instance, so HP and the energy bar are fully
## independent per member (rule: individual bars).

signal hp_changed(unit: BattleUnit, new_health: int)
signal energy_changed(unit: BattleUnit, new_energy: int)
signal defeated(unit: BattleUnit)

const MAX_ENERGY := 5 # energy bar cap, same for every unit

@export var stats: CharacterStats
@export var basic_moves: Array[Move] = []
@export var alteration_moves: Array[Move] = []
@export var is_player_controlled: bool = true

## Enemy-only. If set, this unit ignores Basic/Alteration + energy entirely
## and just cycles through a fixed attack pattern (see EnemyMoveset).
@export var moveset: EnemyMoveset

var current_health: int
var current_energy: int = 0
var is_guarding: bool = false

## Runtime-only state. Units are rebuilt every fight, so these naturally
## start fresh and "last the entire fight".
var bonus_attack: int = 0          # buffs (e.g. Oxypetalum - Strengthen)
var move_uses: Dictionary = {}     # Move -> times used this fight
var stun_turns: int = 0            # turns this unit will lose

func _ready() -> void:
	if stats:
		current_health = stats.max_health

func is_alive() -> bool:
	return current_health > 0

## Attack including buffs. Use this instead of stats.attack in combat.
func get_attack() -> int:
	return stats.attack + bonus_attack

## Applies damage (halved if guarding) and returns the actual amount dealt.
func take_damage(amount: int) -> int:
	var final_amount := amount
	if is_guarding:
		final_amount = int(final_amount * 0.5)
	final_amount = max(0, final_amount)
	current_health = max(0, current_health - final_amount)
	hp_changed.emit(self, current_health)
	if current_health == 0:
		defeated.emit(self)
	return final_amount

## Instant KO that ignores Guard (used by execute effects like Condemn).
func kill() -> void:
	current_health = 0
	hp_changed.emit(self, 0)
	defeated.emit(self)

func heal(amount: int) -> void:
	current_health = min(stats.max_health, current_health + amount)
	hp_changed.emit(self, current_health)

## Rule: filling the bar happens one point per turn taken, up to MAX_ENERGY.
func gain_energy(amount: int = 1) -> void:
	current_energy = min(MAX_ENERGY, current_energy + amount)
	energy_changed.emit(self, current_energy)

func spend_energy(amount: int) -> bool:
	if current_energy < amount:
		return false
	current_energy -= amount
	energy_changed.emit(self, current_energy)
	return true

func record_use(move: Move) -> void:
	move_uses[move] = move_uses.get(move, 0) + 1

func uses_left(move: Move) -> int:
	if move.max_uses_per_battle <= 0:
		return -1 # unlimited
	return max(0, move.max_uses_per_battle - move_uses.get(move, 0))

func can_use_move(move: Move) -> bool:
	if move.max_uses_per_battle > 0 and move_uses.get(move, 0) >= move.max_uses_per_battle:
		return false
	if move.type == Move.Type.ALTERATION:
		return current_energy >= move.energy_cost
	return true

func reset_turn_flags() -> void:
	is_guarding = false

## Speed stat doubles as a flat dodge chance percentage (0-100),
## Darkest Dungeon-style. Rolled by the ATTACKER's target, not the attacker.
func roll_dodge() -> bool:
	var chance: float = clamp(stats.speed, 0, 95) / 100.0
	return randf() < chance
