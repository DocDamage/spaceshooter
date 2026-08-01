class_name VibrationRouter
extends RefCounted

const CATEGORIES := [&"primary_weapon", &"heavy_weapon", &"player_damage", &"shield_break", &"melee", &"spell", &"boss_impact", &"environmental_hazard"]
var settings: SettingsService

func configure(settings_service: SettingsService) -> void: settings = settings_service

func emit(category: StringName, device_id: int, weak: float, strong: float, duration: float) -> bool:
	if category not in CATEGORIES or settings == null or not bool(settings.get_setting(&"vibration_enabled", true)): return false
	var categories: Dictionary = settings.get_setting(&"vibration_categories", {})
	if not bool(categories.get(String(category), true)): return false
	var scale := float(settings.get_setting(&"vibration_strength", 1.0))
	if device_id >= 0: Input.start_joy_vibration(device_id, clampf(weak * scale, 0.0, 1.0), clampf(strong * scale, 0.0, 1.0), maxf(0.0, duration))
	return true
