class_name AchievementService
extends BaseGameService

signal achievement_unlocked(achievement_id: StringName)

var _unlocked: Dictionary = {}
var _platform: PlatformService
var _saves: SaveService
var storage_path := "user://platform/achievements.json"

func _init() -> void:
	service_id = &"achievements"

func initialize(context: Dictionary = {}) -> bool:
	var hub = context.get("hub")
	if hub is ServiceHub:
		_platform = hub.platform
		_saves = hub.saves
	_load_state()
	reconcile_platform()
	is_initialized = true
	return true

func configure_storage(path: String, reload := true) -> bool:
	if not path.begins_with("user://") or not path.ends_with(".json"):
		return false
	storage_path = path
	if reload:
		_unlocked.clear()
		_load_state()
	return true

func unlock(achievement_id: StringName) -> void:
	if achievement_id.is_empty() or _unlocked.has(achievement_id):
		return
	_unlocked[achievement_id] = true
	_persist_state()
	if _platform != null: _platform.unlock_achievement(achievement_id)
	achievement_unlocked.emit(achievement_id)

func is_unlocked(achievement_id: StringName) -> bool:
	return _unlocked.has(achievement_id)

func unlocked_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for achievement_id in _unlocked: result.append(StringName(achievement_id))
	result.sort()
	return result

func reconcile_platform() -> int:
	if _platform == null or not _platform.available:
		return 0
	var reconciled := 0
	for achievement_id in unlocked_ids():
		if _platform.unlock_achievement(achievement_id): reconciled += 1
	return reconciled

func _load_state() -> void:
	if _saves == null:
		return
	var has_generation := FileAccess.file_exists(storage_path) or FileAccess.file_exists("%s.previous" % storage_path) or FileAccess.file_exists("%s.recovery" % storage_path)
	if not has_generation:
		return
	# Achievement reconciliation is an internal startup read and must not replace the
	# profile/checkpoint status shown by the save UI.
	var previous_save_status := _saves.status
	var document := _saves.load_snapshot_recovering(storage_path, false)
	_saves.status = previous_save_status
	for raw_id in document.get("unlocked", []):
		var achievement_id := StringName(raw_id)
		if not achievement_id.is_empty(): _unlocked[achievement_id] = true

func _persist_state() -> Error:
	if _saves == null:
		return ERR_UNCONFIGURED
	return _saves.save_snapshot_atomic({"schema_version": 1, "kind": "achievement_state", "unlocked": unlocked_ids()}, storage_path)
