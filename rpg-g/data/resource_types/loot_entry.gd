class_name LootEntry
extends Resource

## One line of a DropLootAction list: which item, with what chance and how many units.
## Gold is just another item (gold_coins.tres).

## Item that can drop.
@export var item: ItemData = null
## Chance (%) of the item dropping on each roll. 100 = always, 0 = never.
@export_range(0, 100) var chance: int = 100
## Minimum units in the dropped stack (0 allows dropping nothing sometimes).
@export_range(0, 999) var min_amount: int = 1
## Maximum units in the dropped stack.
@export_range(0, 999) var max_amount: int = 1
