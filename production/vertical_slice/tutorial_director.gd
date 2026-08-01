class_name TutorialDirector
extends RefCounted

const TOPICS: Array[StringName] = [&"movement", &"primary_fire", &"focus", &"temporary_upgrade", &"shield", &"spell", &"chain", &"checkpoint", &"optional_objective"]
const ACTIONS := {&"movement": &"move_up", &"primary_fire": &"primary_fire", &"focus": &"focus", &"shield": &"shield", &"spell": &"spell"}

var enabled := true
var completed: Array[StringName] = []
var input: GameInputService
var settings: SettingsService

func configure(input_service: GameInputService, settings_service: SettingsService, tutorial_enabled := true) -> void:
	input = input_service
	settings = settings_service
	enabled = tutorial_enabled

func next_prompt() -> Dictionary:
	if not enabled: return {}
	for topic in TOPICS:
		if topic not in completed:
			var action: StringName = ACTIONS.get(topic, &"")
			return {"topic": topic, "action": action, "prompt": input.get_prompt(action) if input != null and not action.is_empty() else "", "controller_aware": true, "keyboard_aware": true, "reduced_motion": _setting(&"background_motion_reduction", 0.0) > 0.0, "auto_fire": _setting(&"auto_fire", false)}
	return {}

func complete_topic(topic: StringName) -> bool:
	if topic not in TOPICS or topic in completed: return false
	completed.append(topic)
	return true

func skip() -> void:
	enabled = false

func replay() -> void:
	completed.clear()
	enabled = true

func snapshot() -> Dictionary:
	return {"enabled": enabled, "completed": completed.duplicate()}

func restore(data: Dictionary) -> void:
	enabled = bool(data.get("enabled", true))
	completed.assign(data.get("completed", []))

func _setting(key: StringName, fallback: Variant) -> Variant:
	return settings.get_setting(key, fallback) if settings != null else fallback
