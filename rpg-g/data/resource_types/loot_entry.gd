class_name LootEntry
extends Resource

## Una línea de la lista de DropLootAction: qué ítem, con qué probabilidad y cuántas unidades.
## El oro es un ítem más (gold_coins.tres).

## Ítem que puede caer.
@export var item: ItemData = null
## Probabilidad (%) de que el ítem salga en cada tirada. 100 = siempre, 0 = nunca.
@export_range(0, 100) var chance: int = 100
## Unidades mínimas del montón que cae (0 permite que a veces no caiga nada).
@export_range(0, 999) var min_amount: int = 1
## Unidades máximas del montón que cae.
@export_range(0, 999) var max_amount: int = 1
