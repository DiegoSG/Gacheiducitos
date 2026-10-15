extends Node

## Prueba del backup de partidas: escribe un slot falso, lo daña y comprueba que
## SaveSystem lee el backup. Usa solo archivos propios en user:// y los borra al terminar.
## Resultado por consola (PASS/FAIL) y en pantalla.

const TEST_PATH: String = "user://test_save_backup.json"

@onready var _result_label: Label = %ResultLabel

var _failures: int = 0

func _ready() -> void:
	_cleanup()

	# 1. Sin archivo ni backup: diccionario vacío.
	_check(SaveSystem._read_slot_data(TEST_PATH).is_empty(), "sin archivos devuelve vacío")

	# 2. Archivo válido: se lee el principal.
	_write(TEST_PATH, JSON.stringify({"version": 1, "marca": "primera"}))
	_check(SaveSystem._read_slot_data(TEST_PATH).get("marca", "") == "primera", "lee el archivo principal")

	# 3. Al sobrescribir, la versión anterior queda en el backup.
	SaveSystem._backup_slot_file(TEST_PATH)
	_write(TEST_PATH, JSON.stringify({"version": 1, "marca": "segunda"}))
	_check(FileAccess.file_exists(TEST_PATH + SaveSystem.BACKUP_SUFFIX), "crea el backup")
	_check(SaveSystem._read_slot_data(TEST_PATH).get("marca", "") == "segunda", "el principal tiene la versión nueva")

	# 4. Principal dañado: se usa el backup.
	_write(TEST_PATH, "{ esto no es json")
	_check(SaveSystem._read_slot_data(TEST_PATH).get("marca", "") == "primera", "con el principal dañado usa el backup")

	_cleanup()
	var summary: String = "PASS: backup de partidas" if _failures == 0 else "FAIL: %d comprobaciones fallaron" % _failures
	print(summary)
	_result_label.text = summary

func _check(condition: bool, description: String) -> void:
	if condition:
		print("  ok - ", description)
	else:
		_failures += 1
		push_error("  FALLA - " + description)

func _write(path: String, content: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()

func _cleanup() -> void:
	for path: String in [TEST_PATH, TEST_PATH + SaveSystem.BACKUP_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
