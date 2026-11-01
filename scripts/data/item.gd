extends Resource
class_name Item
## A consumable. Quantities are tracked separately in
## BattleManager.party_inventory (Item -> int) so the same Item resource
## can be reused/shared without mutating itself. Crafted at the workshop
## (Preparation) - see ItemLibrary for the real list.

@export var id: String = ""
@export var item_name: String = "Potion"
@export var category: String = ""
@export var cost: int = 0
## Old-style flat heal (battle_demo's Potion). Used only if heal_pct is 0.
@export var heal_amount: int = 30
## Heals this % of the TARGET's max HP, rounded up. For a revive item it is the
## HP% a downed ally comes back with (and what it heals a living ally for).
@export var heal_pct: float = 0.0
@export var revive: bool = false          # if true, can target a downed ally
@export var energy_gain: int = 0          # Energy given to the target
@export var buffs: Array[StatusApplication] = []  # statuses given to the target
@export_multiline var description: String = ""     # Indonesian effect text
