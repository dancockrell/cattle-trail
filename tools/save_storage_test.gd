extends SceneTree

const Storage = preload("res://scripts/save_storage.gd")
var failures: Array[String] = []
var folder := "user://save-storage-test-%s-%s" % [OS.get_process_id(), Time.get_ticks_usec()]


func _initialize() -> void:
	var absolute := ProjectSettings.globalize_path(folder)
	_check(DirAccess.make_dir_absolute(absolute) == OK, "create unique test folder")
	var path := folder + "/save.json"
	var first := {"chapter": 1, "name": "Clear Fork — café", "flags": [true, false, null], "nested": {"cash": 12.5}}
	var second := {"chapter": 2, "cash": 420}
	_check(Storage.read(path).is_empty(), "missing save returns empty dictionary")
	_check(Storage.write(path, first), "roundtrip writes")
	_check(_same_json(Storage.read(path), first), "roundtrip preserves JSON values")
	_check(Storage.write(path, second), "replacement writes")
	_check(_same_json(Storage.read(path), second), "replacement is current")
	_check(_same_json(Storage.read(path + ".bak"), first), "previous valid primary preserved as backup")
	_write_raw(path, "{ malformed")
	_check(_same_json(Storage.read(path), first), "malformed primary falls back to backup")
	_check(Storage.write(path, second), "write repairs malformed primary")
	_check(_same_json(Storage.read(path + ".bak"), first), "malformed primary does not overwrite valid backup")
	_write_raw(path, "[]")
	_check(_same_json(Storage.read(path), first), "non-dictionary JSON falls back to backup")
	_check(Storage.write(path, {}), "empty dictionary is a valid save")
	_check(Storage.read(path).is_empty(), "valid empty primary wins over nonempty backup")
	_check(Storage.write(path, second), "restore current state for failure checks")
	_check(not Storage.write(path, {"bad": NAN}), "non-finite JSON rejected")
	_check(_same_json(Storage.read(path), second), "invalid payload does not destroy current save")
	# A directory at the backup destination forces a deterministic commit failure.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".bak"))
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(path + ".bak"))
	_check(not Storage.write(path, first), "blocked backup replacement reports failed write")
	_check(_same_json(Storage.read(path), second), "failed replacement leaves old primary intact")
	_check(not Storage.write(folder + "/missing/save.json", first), "missing parent reports failed write")
	_check(_same_json(Storage.read(path), second), "unrelated open failure leaves old save intact")
	var directory := DirAccess.open(folder)
	_check(directory != null, "test folder still exists")
	if directory != null:
		for item in directory.get_files():
			_check(not ".stage-" in item, "no staging debris after handled writes: " + item)
	_clean_test_folder(absolute)
	_check(not DirAccess.dir_exists_absolute(absolute), "unique test folder cleaned")
	if failures.is_empty():
		print("SAVE STORAGE PASS: roundtrip, replacement, backup fallback, corrupt-primary repair, failed-write preservation, cleanup")
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _write_raw(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "test corruption fixture opens")
	if file != null:
		file.store_string(text)
		file.close()


func _clean_test_folder(absolute: String) -> void:
	# Only this unique test folder and its known empty backup directory are touched.
	var directory := DirAccess.open(absolute)
	if directory == null:
		return
	for item in directory.get_files():
		DirAccess.remove_absolute(absolute.path_join(item))
	for item in directory.get_directories():
		DirAccess.remove_absolute(absolute.path_join(item))
	DirAccess.remove_absolute(absolute)


func _same_json(actual: Dictionary, expected: Dictionary) -> bool:
	# JSON numbers decode as floats in Godot; compare against equivalent decoded data.
	return actual == JSON.parse_string(JSON.stringify(expected, "", true, true))
