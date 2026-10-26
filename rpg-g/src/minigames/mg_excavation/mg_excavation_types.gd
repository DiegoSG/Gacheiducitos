extends Node

# Tile types for the Supaplex engine
# New values go at the end so saved levels and resources keep their meaning.
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
	BOMB_PICKUP,
	PLAYER_START, # Editor-only: the loader turns it into EMPTY plus the player's start cell
}

# Win conditions for the engine
enum WinCondition {
	ALL_COINS,
	TARGET_AMOUNT,
	SPECIFIC_ITEM,
	EXIT_ONLY, # No goal: the exit is open from the start
}
