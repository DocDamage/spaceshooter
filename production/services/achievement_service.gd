class_name AchievementService
extends BaseGameService

signal achievement_unlocked(achievement_id: StringName)

var _unlocked: Dictionary = {}
var _platform: PlatformService

func _init() -> void:
	service_id = &"achievements"

func initialize(context: Dictionary = {}) -> bool:
	var hub = context.get("hub")
	if hub is ServiceHub: _platform = hub.platform
	is_initialized = true
	return true

func unlock(achievement_id: StringName) -> void:
	if achievement_id.is_empty() or _unlocked.has(achievement_id):
		return
	_unlocked[achievement_id] = true
	if _platform != null: _platform.unlock_achievement(achievement_id)
	achievement_unlocked.emit(achievement_id)

func is_unlocked(achievement_id: StringName) -> bool:
	return _unlocked.has(achievement_id)
