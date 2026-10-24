extends Resource
class_name CharacterStats
## Exactly 4 base stats, DQ/FF-simple on purpose:
##
##   Health      - max HP.
##   Attack      - powers Basic moves (the "physical" stat).
##   Capability  - powers Alteration moves (the "magic/special" stat).
##   Speed       - doubles as flat dodge chance % (Darkest Dungeon style),
##                 NOT used for turn order. Turn order stays team-vs-team.
##
## Crit chance is NOT a stat anymore - it's a fixed global rate (1 in 14)
## defined once in BattleManager and applied the same way to everyone.

@export var character_name: String = "Unnamed"
@export var max_health: int = 100
@export var attack: int = 10
@export var capability: int = 10
@export var speed: int = 10 # 10 = 10% chance to dodge an incoming hit
