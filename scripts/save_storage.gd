class_name SaveStorage
extends RefCounted
## Single-writer JSON storage. A readable .bak survives interrupted replacement.
## An optional schema predicate rejects invalid primary data before backup fallback.
## Validators receive deep copies; accepted data is returned without their mutations.

static func read(path: String, validator: Callable = Callable()) -> Dictionary:
	var primary := _read_file(path)
	if _accepted(primary, validator):
		return primary.data
	var backup := _read_file(path + ".bak")
	return backup.data if _accepted(backup, validator) else {}


static func _accepted(record: Dictionary, validator: Callable) -> bool:
	if not record.valid:
		return false
	if validator.is_null():
		return true
	if not validator.is_valid():
		return false
	var verdict: Variant = validator.call(record.data.duplicate(true))
	return verdict is bool and verdict


static func write(path: String, data: Dictionary) -> bool:
	if path.is_empty() or not _json_compatible(data):
		return false
	var destination := ProjectSettings.globalize_path(path)
	if DirAccess.dir_exists_absolute(destination):
		return false
	var suffix := ".stage-%s-%s" % [OS.get_process_id(), Time.get_ticks_usec()]
	var staged := destination + suffix
	var backup_staged := destination + ".bak" + suffix
	var payload := JSON.stringify(data, "\t", true, true)
	if not _write_and_verify(staged, payload):
		_remove_file(staged)
		return false
	var previous := _read_file(destination)
	if previous.valid:
		# Never replace a good backup with a corrupt primary.
		if not _write_and_verify(backup_staged, previous.text):
			_remove_file(staged)
			_remove_file(backup_staged)
			return false
		if not _replace_file(backup_staged, destination + ".bak", suffix):
			_remove_file(staged)
			_remove_file(backup_staged)
			return false
	var committed := _replace_file(staged, destination, suffix)
	if not committed:
		_remove_file(staged)
	return committed


static func _read_file(path: String) -> Dictionary:
	var invalid := {"valid": false, "data": {}, "text": ""}
	if path.is_empty() or not FileAccess.file_exists(path):
		return invalid
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return invalid
	var payload := file.get_as_text()
	var error := file.get_error()
	file.close()
	if error != OK and error != ERR_FILE_EOF:
		return invalid
	var parser := JSON.new()
	if parser.parse(payload) != OK or not parser.data is Dictionary:
		return invalid
	return {"valid": true, "data": parser.data, "text": payload}


static func _write_and_verify(path: String, payload: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(payload)
	file.flush()
	var error := file.get_error()
	file.close()
	return error == OK and _read_file(path).valid


static func _replace_file(staged: String, destination: String, suffix: String) -> bool:
	# Explicit rollback works on Windows without relying on overwrite-rename behavior.
	if DirAccess.dir_exists_absolute(destination):
		return false
	var rollback := destination + suffix + ".previous"
	var had_previous := FileAccess.file_exists(destination)
	if had_previous and DirAccess.rename_absolute(destination, rollback) != OK:
		return false
	if DirAccess.rename_absolute(staged, destination) != OK:
		if had_previous:
			DirAccess.rename_absolute(rollback, destination)
		return false
	_remove_file(rollback)
	return true


static func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func _json_compatible(value: Variant, depth: int = 0) -> bool:
	# Reject unsupported objects, non-finite numbers, cycles, and excessive nesting.
	if depth > 64:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return true
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_ARRAY:
			for child in value:
				if not _json_compatible(child, depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			for key in value:
				if not key is String or not _json_compatible(value[key], depth + 1):
					return false
			return true
	return false
