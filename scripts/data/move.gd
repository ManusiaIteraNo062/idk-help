extends Resource
class_name Move
## A single Basic or Alteration move. Basic moves are always usable;
## Alteration moves cost energy from the user's own bar (rule 5).
##
## Damage formula for a hit:
##   power + (Attack or Capability) * scaling_mult + Speed * speed_mult
## Attack is used for BASIC moves, Capability for ALTERATION moves.

enum Type { BASIC, ALTERATION }
enum Target { SINGLE_ENEMY, ALL_ENEMIES, SINGLE_ALLY, ALL_ALLIES, SELF }

@export var move_name: String = "Attack"
@export var type: Type = Type.BASIC
@export var target_type: Target = Target.SINGLE_ENEMY
@export var energy_cost: int = 0 # only relevant when type == ALTERATION
@export var power: int = 10
@export var is_heal: bool = false # true for support Alterations, e.g. Cure
@export_multiline var description: String = ""

# --- Damage shaping ---------------------------------------------------------
@export var scaling_mult: float = 1.0   # multiplier on the scaling stat (Condemn = 20)
@export var speed_mult: float = 0.0     # adds Speed * this to damage (Stylish = 1)
@export var hits: int = 1               # multi-hit moves (Heroic = 2)

# --- Extra effects ----------------------------------------------------------
@export var lifesteal: float = 0.0      # fraction of damage dealt healed back to the user (Absorption = 1.0)
@export var stun_turns: int = 0         # > 0 stuns the target on hit (Backhand = 1)

## Execute: if > 0, after the hit the target is KO'd when its HP is below
##   execute_base + Capability * execute_per_cap
## (Condemn: base 50, per_cap 7.5 = 50 + (Capability / 2) * 15)
@export var execute_base: int = 0
@export var execute_per_cap: float = 0.0

## Self-buff to Attack: gain = buff_attack_flat + Capability * buff_attack_cap_mult
## (Strengthen: flat 5, cap_mult 1.0). Lasts the whole fight.
@export var buff_attack_flat: int = 0
@export var buff_attack_cap_mult: float = 0.0

## 0 = unlimited. Otherwise the move can only be used this many times per battle.
@export var max_uses_per_battle: int = 0

## false = the move still has to connect (dodge applies) but deals no damage;
## only its side effects happen (Taksaka - Secure: stun + self-heal).
@export var deals_damage: bool = true

## On hit, the user heals max_health * Capability * this.
## (Taksaka - Secure: 1.0 / 125.0 = Capability/125 of max HP)
@export var self_heal_max_hp_per_cap: float = 0.0

## Percent-of-max-HP heals (set is_heal = true): the target recovers
##   (heal_pct_base + Capability * heal_pct_per_cap) % of ITS max HP.
## (WYG-01 // Supplication: base 10, per_cap 0.5 = 10% + Capability/2 %)
## If both are 0, the old flat heal (power + Capability) is used.
@export var heal_pct_base: float = 0.0
@export var heal_pct_per_cap: float = 0.0
