class_name SaveService
extends BaseGameService

signal save_status_changed(status: StringName)
signal recovery_required(report: Dictionary)

const SCHEMA_VERSION := 9
const DEFAULT_ROOT := "user://saves"
const MAX_SAVE_FILE_BYTES := 8 * 1024 * 1024
const MAX_PAYLOAD_BYTES := 6 * 1024 * 1024
const MAX_NESTING_DEPTH := 32
const MAX_CONTAINER_ENTRIES := 20000
const MAX_STRING_BYTES := 1024 * 1024

var status: StringName = &"idle"
var last_snapshot: Dictionary = {}
var storage_root := DEFAULT_ROOT
var migration_log: Array[Dictionary] = []
var last_recovery_report: Dictionary = {}
var last_error_message := ""

func _init() -> void:
	service_id = &"saves"

func configure_storage(path: String) -> void:
	storage_root = path.trim_suffix("/")

func profile_path(profile_id: StringName) -> String:
	return "%s/%s/profile.json" % [storage_root, _safe_id(profile_id)]

func checkpoint_path(profile_id: StringName) -> String:
	return "%s/%s/checkpoint.json" % [storage_root, _safe_id(profile_id)]

func save_snapshot(snapshot: Dictionary) -> Error:
	status = &"saving"
	save_status_changed.emit(status)
	last_snapshot = snapshot.duplicate(true)
	status = &"saved"
	save_status_changed.emit(status)
	return OK

func save_profile(profile_id: StringName, snapshot: Dictionary) -> Error:
	return save_snapshot_atomic(snapshot, profile_path(profile_id))

func load_profile(profile_id: StringName) -> Dictionary:
	return load_snapshot_recovering(profile_path(profile_id), true)

func save_checkpoint(profile_id: StringName, checkpoint: Dictionary) -> Error:
	var required := [&"checkpoint_id", &"mission_id", &"seed", &"route", &"session_run_id", &"participants", &"objective_state", &"temporary_upgrades", &"pending_rewards"]
	for key in required:
		if not checkpoint.has(key):
			return ERR_INVALID_DATA
	return save_snapshot_atomic({"schema_version": SCHEMA_VERSION, "kind": "checkpoint", "checkpoint": checkpoint}, checkpoint_path(profile_id))

func load_checkpoint(profile_id: StringName) -> Dictionary:
	var document := load_snapshot_recovering(checkpoint_path(profile_id), false)
	return document.get("checkpoint", {}).duplicate(true) if document.get("checkpoint") is Dictionary else {}

func clear_checkpoint(profile_id: StringName) -> Error:
	var path := checkpoint_path(profile_id)
	if not FileAccess.file_exists(path):
		return OK
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func save_snapshot_atomic(snapshot: Dictionary, path: String = "user://profile_v9.json") -> Error:
	_set_status(&"saving")
	var document := _make_document(snapshot)
	var validation := _validate_document(document)
	if validation.error != OK:
		last_error_message = validation.message
		_set_status(&"error")
		return validation.error
	var directory_error := _ensure_parent(path)
	if directory_error != OK:
		last_error_message = "Could not create save directory (%d)." % directory_error
		_set_status(&"error")
		return directory_error
	var temp_path := "%s.tmp" % path
	var previous_path := "%s.previous" % path
	var recovery_path := "%s.recovery" % path
	var write_error := _write_document(temp_path, document)
	if write_error != OK:
		last_error_message = "Could not write temporary save (%d)." % write_error
		_set_status(&"error")
		return write_error
	var temp_validation := _read_document(temp_path, false)
	if temp_validation.error != OK:
		last_error_message = "Temporary save validation failed: %s" % temp_validation.message
		_delete_if_exists(temp_path)
		_set_status(&"error")
		return temp_validation.error
	# Keep two known-good generations. A failed replacement can always roll back.
	if FileAccess.file_exists(previous_path):
		var rotate_error := _copy_file(previous_path, recovery_path)
		if rotate_error != OK:
			_delete_if_exists(temp_path)
			_set_status(&"error")
			return rotate_error
	if FileAccess.file_exists(path):
		var backup_check := _read_document(path, false)
		if backup_check.error == OK:
			var backup_error := _copy_file(path, previous_path)
			if backup_error != OK:
				_delete_if_exists(temp_path)
				_set_status(&"error")
				return backup_error
	var absolute_temp := ProjectSettings.globalize_path(temp_path)
	var absolute_target := ProjectSettings.globalize_path(path)
	var staged_old := "%s.replace_old" % path
	_delete_if_exists(staged_old)
	if FileAccess.file_exists(path):
		var stage_error := DirAccess.rename_absolute(absolute_target, ProjectSettings.globalize_path(staged_old))
		if stage_error != OK:
			_delete_if_exists(temp_path)
			_set_status(&"error")
			return stage_error
	var replace_error := DirAccess.rename_absolute(absolute_temp, absolute_target)
	if replace_error != OK:
		if FileAccess.file_exists(staged_old):
			DirAccess.rename_absolute(ProjectSettings.globalize_path(staged_old), absolute_target)
		_set_status(&"error")
		return replace_error
	_delete_if_exists(staged_old)
	last_snapshot = snapshot.duplicate(true)
	_set_status(&"saved")
	return OK

func load_snapshot(path: String = "user://profile_v9.json") -> Dictionary:
	return load_snapshot_recovering(path, false)

func load_snapshot_recovering(path: String, migrate := true) -> Dictionary:
	last_recovery_report = {"requested_path": path, "attempts": [], "recovered": false, "message": ""}
	for candidate in [path, "%s.previous" % path, "%s.recovery" % path]:
		var result := _read_document(candidate, migrate)
		last_recovery_report.attempts.append({"path": candidate, "error": result.error, "message": result.message})
		if result.error == OK:
			if migrate and bool(result.get("migrated", false)) and candidate == path:
				var migration_backup := "%s.pre_migration_v%d" % [path, int(result.get("source_version", 0))]
				var backup_error := _copy_file(path, migration_backup)
				if backup_error != OK or save_snapshot_atomic(result.payload, path) != OK:
					last_recovery_report.message = "Migration was validated but could not be committed; the original was preserved."
					_set_status(&"migration_failed")
					return {}
			last_recovery_report.recovered = candidate != path
			last_recovery_report.source_path = candidate
			last_recovery_report.message = "Recovered from backup." if candidate != path else "Save loaded."
			if candidate != path:
				_set_status(&"recovered")
				recovery_required.emit(last_recovery_report.duplicate(true))
			else:
				_set_status(&"loaded")
			return result.payload
	_set_status(&"corrupt")
	last_recovery_report.message = "No valid save or backup was found. The files were preserved for diagnostics."
	recovery_required.emit(last_recovery_report.duplicate(true))
	return {}

func export_diagnostics(path: String = "user://save_recovery_diagnostics.json") -> Error:
	return _write_text(path, JSON.stringify({"schema_version": SCHEMA_VERSION, "generated_unix": Time.get_unix_time_from_system(), "status": status, "migration_log": migration_log, "recovery": last_recovery_report}, "  "))

func report_required_content_error(profile_id: StringName, validation: Dictionary) -> void:
	last_recovery_report = {"profile_id": profile_id, "recovered": false, "message": "Required equipped content is unavailable. Restore the content or choose a backup; the profile was not reset.", "attempts": [], "content_validation": validation.duplicate(true)}
	_set_status(&"content_missing")
	recovery_required.emit(last_recovery_report.duplicate(true))

func _make_document(payload: Dictionary) -> Dictionary:
	var migrated_payload := payload.duplicate(true)
	if not migrated_payload.has("schema_version"):
		migrated_payload.schema_version = SCHEMA_VERSION
	var payload_text := JSON.stringify(migrated_payload)
	return {"format": "galax_hero_save", "schema_version": SCHEMA_VERSION, "checksum_algorithm": "sha256", "checksum": payload_text.sha256_text(), "payload_json": payload_text}

func _read_document(path: String, migrate: bool) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": ERR_FILE_NOT_FOUND, "message": "File is missing.", "payload": {}}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": FileAccess.get_open_error(), "message": "File could not be opened.", "payload": {}}
	if file.get_length() > MAX_SAVE_FILE_BYTES:
		file.close()
		return {"error": ERR_FILE_CORRUPT, "message": "Save exceeds the safe file-size limit.", "payload": {}}
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	if parse_error != OK or not json.data is Dictionary:
		return {"error": ERR_PARSE_ERROR, "message": "JSON parse failed at line %d: %s" % [json.get_error_line(), json.get_error_message()], "payload": {}}
	var checked := _validate_document(json.data)
	if checked.error != OK:
		return checked
	var payload: Dictionary = checked.payload.duplicate(true)
	var source_version := int(payload.get("schema_version", 0))
	var was_migrated := false
	if migrate:
		var migrated := SaveSchemaMigrator.migrate(payload)
		if not migrated.success:
			return {"error": ERR_INVALID_DATA, "message": migrated.message, "payload": {}}
		payload = migrated.data
		was_migrated = source_version != int(payload.get("schema_version", source_version))
		if not migrated.log.is_empty():
			migration_log.append_array(migrated.log)
	return {"error": OK, "message": "Valid save.", "payload": payload, "migrated": was_migrated, "source_version": source_version}

func _validate_document(document: Dictionary) -> Dictionary:
	if document.get("format") != "galax_hero_save" or not document.get("payload_json") is String:
		return {"error": ERR_FILE_CORRUPT, "message": "Save envelope is invalid.", "payload": {}}
	var payload_text: String = document.payload_json
	if payload_text.to_utf8_buffer().size() > MAX_PAYLOAD_BYTES:
		return {"error": ERR_FILE_CORRUPT, "message": "Save payload exceeds the safe size limit.", "payload": {}}
	if String(document.get("checksum", "")) != payload_text.sha256_text():
		return {"error": ERR_FILE_CORRUPT, "message": "Checksum verification failed.", "payload": {}}
	var parsed = JSON.parse_string(payload_text)
	if not parsed is Dictionary:
		return {"error": ERR_FILE_CORRUPT, "message": "Save payload is not a dictionary.", "payload": {}}
	var bound_error := _validate_value_bounds(parsed)
	if not bound_error.is_empty():
		return {"error": ERR_FILE_CORRUPT, "message": bound_error, "payload": {}}
	return {"error": OK, "message": "Valid save.", "payload": parsed}

func _write_document(path: String, document: Dictionary) -> Error:
	return _write_text(path, JSON.stringify(document, "  "))

func _write_text(path: String, text: String) -> Error:
	if text.to_utf8_buffer().size() > MAX_SAVE_FILE_BYTES:
		return ERR_INVALID_DATA
	var error := _ensure_parent(path)
	if error != OK:
		return error
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.flush()
	file.close()
	return OK

func _ensure_parent(path: String) -> Error:
	var parent := ProjectSettings.globalize_path(path).get_base_dir()
	var error := DirAccess.make_dir_recursive_absolute(parent)
	return OK if error == ERR_ALREADY_EXISTS else error

func _copy_file(source: String, target: String) -> Error:
	_delete_if_exists(target)
	return DirAccess.copy_absolute(ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(target))

func _delete_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _safe_id(value: StringName) -> String:
	var safe := InputSanitizer.safe_storage_key(String(value))
	return safe if not safe.is_empty() else "invalid_profile"

func _validate_value_bounds(value: Variant) -> String:
	return _validate_value_bounds_recursive(value, 0, [0])

func _validate_value_bounds_recursive(value: Variant, depth: int, budget: Array[int]) -> String:
	if depth > MAX_NESTING_DEPTH:
		return "Save nesting exceeds the safe depth limit."
	if value is Dictionary:
		budget[0] += value.size()
		if budget[0] > MAX_CONTAINER_ENTRIES: return "Save contains too many fields."
		for key in value:
			if str(key).to_utf8_buffer().size() > MAX_STRING_BYTES: return "Save field name exceeds the safe length limit."
			var error := _validate_value_bounds_recursive(value[key], depth + 1, budget)
			if not error.is_empty(): return error
	elif value is Array:
		budget[0] += value.size()
		if budget[0] > MAX_CONTAINER_ENTRIES: return "Save contains too many entries."
		for entry in value:
			var error := _validate_value_bounds_recursive(entry, depth + 1, budget)
			if not error.is_empty(): return error
	elif value is String and value.to_utf8_buffer().size() > MAX_STRING_BYTES:
		return "Save string exceeds the safe length limit."
	return ""

func _set_status(value: StringName) -> void:
	status = value
	save_status_changed.emit(status)
