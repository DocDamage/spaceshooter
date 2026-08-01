class_name LocalLeaderboard
extends RefCounted

var storage_path := "user://leaderboards_v1.json"
var maximum_entries := 20
var _boards: Dictionary = {}

func configure_storage(path: String) -> void:
	storage_path = path

func submit(board_id: StringName, entry: Dictionary) -> bool:
	if board_id.is_empty() or not entry.has("score") or not entry.has("effective_difficulty") or not entry.has("active_assists"):
		return false
	var normalized := entry.duplicate(true)
	normalized["recorded_unix"] = int(normalized.get("recorded_unix", Time.get_unix_time_from_system()))
	if not _boards.has(board_id): _boards[board_id] = []
	var board: Array = _boards[board_id]
	board.append(normalized)
	board.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.score) == int(b.score): return float(a.get("elapsed_seconds", INF)) < float(b.get("elapsed_seconds", INF))
		return int(a.score) > int(b.score))
	if board.size() > maximum_entries: board.resize(maximum_entries)
	return true

func entries(board_id: StringName) -> Array:
	return (_boards.get(board_id, []) as Array).duplicate(true)

func save() -> Error:
	var parent := ProjectSettings.globalize_path(storage_path).get_base_dir()
	var dir_error := DirAccess.make_dir_recursive_absolute(parent)
	if dir_error not in [OK, ERR_ALREADY_EXISTS]: return dir_error
	var file := FileAccess.open(storage_path, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"schema_version": 1, "boards": _boards}, "  "))
	return OK

func load() -> Error:
	if not FileAccess.file_exists(storage_path): return OK
	var file := FileAccess.open(storage_path, FileAccess.READ)
	if file == null: return FileAccess.get_open_error()
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or int(parsed.get("schema_version", 0)) != 1: return ERR_FILE_CORRUPT
	_boards = parsed.get("boards", {}).duplicate(true)
	return OK
