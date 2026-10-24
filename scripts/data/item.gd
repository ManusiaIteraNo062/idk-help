extends Resource
class_name Item
## A consumable. Quantities are tracked separately in
## BattleManager.party_inventory (Item -> int) so the same Item resource
## can be reused/shared without mutating itself.

@export var item_name: String = "Potion"
@export var heal_amount: int = 30
@export var revive: bool = false # if true, can target a downed ally
@export_multiline var description: String = ""
