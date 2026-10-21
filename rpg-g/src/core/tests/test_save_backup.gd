extends Node

## Save backup test: writes a fake slot, corrupts it and checks that
## SaveSystem reads the backup. It only uses its own files in user:// and deletes them when done.
## Result in the console (PASS/FAIL) and on screen.

const TEST_PATH: String = "user://test_save_backup.json"

@onready var _result_label: Label = %ResultLabel

var _failures: int = 0

func _ready() -> void:
	_cleanup()

	# 1. No file or backup: empty dictionary.
	_check(SaveSystem._read_slot_data(TEST_PATH).is_empty(), "returns empty when there are no files")

	# 2. Valid file: the main file is read.
	_write(TEST_PATH, JSON.stringify({"version": 1, "marca": "primera"}))
	_check(SaveSystem._read_slot_data(TEST_PATH).get("marca", "") == "primera", "reads the main file")

	# 3. When overwriting, the previous version is kept in the backup.
	SaveSystem._backup_slot_file(TEST_PATH)
	_write(TEST_PATH, JSON.stringify({"version": 1, "marca": "segunda"}))
	_check(FileAccess.file_exists(TEST_PATH + SaveSystem.BACKUP_SUFFIX), "creates the backup")
	_check(SaveSystem._read_slot_data(TEST_PATH).get("marca", "") == "segunda", "the main file has the new version")

	# 4. Main file corrupted: the backup is used.
	_write(TEST_PATH, "{ esto no es json")
	_check(SaveSystem._read_slot_data(TEST_PATH).get("marca", "") == "primera", "with the main file corrupted, uses the backup")

	_cleanup()
	var summary: String = "PASS: save backup" if _failures == 0 else "FAIL: %d checks failed" % _failures
	print(summary)
	_result_label.text = summary

func _check(condition: bool, description: String) -> void:
	if condition:
		print("  ok - ", description)
	else:
		_failures += 1
		push_error("  FAIL - " + description)

func _write(path: String, content: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()

func _cleanup() -> void:
	for path: String in [TEST_PATH, TEST_PATH + SaveSystem.BACKUP_SUFFIX]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
