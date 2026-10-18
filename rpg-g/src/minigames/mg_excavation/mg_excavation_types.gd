extends Node

# Tile types for the Supaplex engine
enum TileType {
	EMPTY,
	TIERRA,
	PIEDRA,
	MURO_IRROMPIBLE,
	MURO_ROMPIBLE,
	ITEM_MISION,
	ITEM_RECOMPENSA,
	BOMBA,
	ENEMIGO,
	SALIDA,
	TRAMPA_BLOQUEO,
	ITEM_INVENTARIO,
	BOMB_PICKUP
}

# Win conditions for the engine
enum WinCondition {
	ALL_COINS,
	TARGET_AMOUNT,
	SPECIFIC_ITEM
}
