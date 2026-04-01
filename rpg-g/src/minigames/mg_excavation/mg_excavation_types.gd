extends Node

# Tipos de tiles para el motor de Supaplex
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
	TRAMPA_BLOQUEO
}

# Condiciones de victoria para el motor
enum WinCondition {
	ALL_COINS,
	TARGET_AMOUNT,
	SPECIFIC_ITEM
}
