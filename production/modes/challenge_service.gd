class_name ChallengeService
extends RefCounted

var completion_history: Dictionary = {}
var saved_definitions: Dictionary = {}
var storage_path := "user://challenge_history_v1.json"

func configure_storage(path: String) -> void: storage_path = path

func definition_for(period: StringName, unix_time: int, content_revision := "phase17") -> Dictionary:
	var date: Dictionary = Time.get_datetime_dict_from_unix_time(unix_time)
	var bucket: String = "%04d-%02d-%02d" % [date.year, date.month, date.day]
	if period == &"weekly":
		var day_number := int(unix_time / 86400.0)
		bucket = "week-%d" % int(day_number / 7)
	var challenge_id: StringName = StringName("challenge.%s.%s" % [period, bucket])
	var seed: int = absi((String(challenge_id) + ":" + content_revision).hash())
	var choices: Array[StringName] = [&"aggressive_enemies", &"fragile_shields", &"dense_formations", &"limited_spells", &"accelerated_projectiles"]
	var mutators: Array[StringName] = [choices[seed % choices.size()], choices[(seed / choices.size() + 2) % choices.size()]]
	if mutators[0] == mutators[1]: mutators.resize(1)
	var definition: Dictionary = {"challenge_id": challenge_id, "period": period, "bucket": bucket, "seed": seed, "mutators": mutators, "content_revision": content_revision}
	saved_definitions[challenge_id] = definition.duplicate(true)
	return definition

func record_completion(definition: Dictionary, result: Dictionary) -> bool:
	var challenge_id := StringName(definition.get("challenge_id", ""))
	if challenge_id.is_empty(): return false
	var candidate: Dictionary = result.duplicate(true)
	var prior: Dictionary = completion_history.get(challenge_id, {})
	if prior.is_empty() or int(candidate.get("score", 0)) > int(prior.get("score", 0)):
		completion_history[challenge_id] = candidate
	return true

func snapshot() -> Dictionary:
	return {"schema_version": 1, "definitions": saved_definitions.duplicate(true), "completion_history": completion_history.duplicate(true)}

func restore(data: Dictionary) -> bool:
	if int(data.get("schema_version", 0)) != 1: return false
	saved_definitions = data.get("definitions", {}).duplicate(true)
	completion_history = data.get("completion_history", {}).duplicate(true)
	return true

func save() -> Error:
	var directory := ProjectSettings.globalize_path(storage_path).get_base_dir()
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error not in [OK, ERR_ALREADY_EXISTS]: return error
	var file := FileAccess.open(storage_path, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(snapshot(), "  "))
	return OK

func load() -> Error:
	if not FileAccess.file_exists(storage_path): return OK
	var file := FileAccess.open(storage_path, FileAccess.READ)
	if file == null: return FileAccess.get_open_error()
	var parsed = JSON.parse_string(file.get_as_text())
	return OK if parsed is Dictionary and restore(parsed) else ERR_FILE_CORRUPT
