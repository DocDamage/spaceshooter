class_name SettingsService
extends BaseGameService

signal setting_changed(key: StringName, value: Variant)
signal settings_loaded
signal settings_saved

const SETTINGS_PATH := "user://settings_v1.json"
const SCHEMA_VERSION := 1
const MAX_SETTINGS_FILE_BYTES := 262_144

const DEFAULTS := {
	&"master_volume": 1.0,
	&"music_volume": 1.0,
	&"ambience_volume": 1.0,
	&"weapons_volume": 1.0,
	&"explosions_volume": 1.0,
	&"player_volume": 1.0,
	&"enemies_volume": 1.0,
	&"dialogue_volume": 1.0,
	&"ui_volume": 1.0,
	&"audio_muted": false,
	&"dynamic_range": "full",
	&"window_mode": "windowed",
	&"vsync_enabled": true,
	&"frame_rate_limit": 60,
	&"diagnostics_visible": true,
	&"locale": "en",
	&"controller_dead_zone": 0.18,
	&"analog_response_curve": 1.0,
	&"aim_sensitivity": 1.0,
	&"movement_sensitivity": 1.0,
	&"analog_movement": true,
	&"always_show_hitbox": false,
	&"vibration_enabled": true,
	&"vibration_strength": 1.0,
	&"vibration_categories": {"primary_weapon": true, "heavy_weapon": true, "player_damage": true, "shield_break": true, "melee": true, "spell": true, "boss_impact": true, "environmental_hazard": true},
	&"glyph_family": "auto",
	&"colorblind_filter": "off",
	&"projectile_outline": true,
	&"player_outline": true,
	&"hostile_bullet_color": "ff566d",
	&"friendly_bullet_color": "62dcff",
	&"screen_shake_scale": 1.0,
	&"flash_reduction": 0.0,
	&"particle_density": 1.0,
	&"background_motion_reduction": 0.0,
	&"ui_scale": 1.0,
	&"text_scale": 1.0,
	&"text_speed": 1.0,
	&"subtitles_enabled": true,
	&"subtitle_background": true,
	&"subtitle_background_opacity": 0.82,
	&"aim_assistance": 0.0,
	&"game_speed_assistance": 1.0,
	&"auto_fire": false,
	&"focus_toggle": false,
	&"shield_toggle": false,
	&"system_damage_enabled": true,
	&"engine_damage_enabled": true,
	&"weapons_damage_enabled": true,
	&"shield_generator_damage_enabled": true,
	&"controls_damage_enabled": true,
	&"reactor_damage_enabled": true,
	&"wingman_command_damage_enabled": true,
	&"simplified_patterns": false,
	&"invulnerability_assist": false,
}

const NUMERIC_RANGES := {
	&"master_volume": Vector2(0.0, 1.0), &"music_volume": Vector2(0.0, 1.0), &"ambience_volume": Vector2(0.0, 1.0),
	&"weapons_volume": Vector2(0.0, 1.0), &"explosions_volume": Vector2(0.0, 1.0), &"player_volume": Vector2(0.0, 1.0),
	&"enemies_volume": Vector2(0.0, 1.0), &"dialogue_volume": Vector2(0.0, 1.0), &"ui_volume": Vector2(0.0, 1.0),
	&"controller_dead_zone": Vector2(0.05, 0.75), &"analog_response_curve": Vector2(0.5, 2.0), &"aim_sensitivity": Vector2(0.25, 2.0), &"movement_sensitivity": Vector2(0.25, 2.0),
	&"vibration_strength": Vector2(0.0, 1.0), &"screen_shake_scale": Vector2(0.0, 1.0), &"flash_reduction": Vector2(0.0, 1.0),
	&"particle_density": Vector2(0.0, 1.0), &"background_motion_reduction": Vector2(0.0, 1.0), &"ui_scale": Vector2(0.75, 1.5),
	&"text_scale": Vector2(0.75, 1.75), &"text_speed": Vector2(0.25, 3.0), &"subtitle_background_opacity": Vector2(0.25, 1.0),
	&"aim_assistance": Vector2(0.0, 1.0), &"game_speed_assistance": Vector2(0.5, 1.0)
}

const STRING_OPTIONS := {
	&"dynamic_range": ["full", "night"], &"window_mode": ["windowed", "fullscreen", "borderless"],
	&"locale": ["en", "qps_ploc", "qps_rtl"], &"glyph_family": ["auto", "xbox", "playstation", "nintendo"],
	&"colorblind_filter": ["off", "protanopia", "deuteranopia", "tritanopia"],
	&"hostile_bullet_color": ["ff566d", "ff9f43", "ff5ee7"], &"friendly_bullet_color": ["62dcff", "66ff9a", "ffffff"]
}

var _values: Dictionary = {}
var _bindings: Dictionary = {}
var storage_path := SETTINGS_PATH

func _init() -> void:
	service_id = &"settings"
	_values = DEFAULTS.duplicate(true)

func initialize(_context: Dictionary = {}) -> bool:
	load_settings()
	is_initialized = true
	return true

func get_setting(key: StringName, fallback: Variant = null) -> Variant:
	return _values.get(key, fallback)

func set_setting(key: StringName, value: Variant, persist := true) -> void:
	var safe_value: Variant = _sanitize_known_setting(key, value)
	if _values.get(key) == safe_value:
		return
	_values[key] = safe_value
	setting_changed.emit(key, safe_value)
	if persist:
		save_settings()

func set_bindings(bindings: Dictionary, persist := true) -> void:
	_bindings = bindings.duplicate(true)
	if persist:
		save_settings()

func get_bindings() -> Dictionary:
	return _bindings.duplicate(true)

func restore_defaults(persist := true) -> void:
	_values = DEFAULTS.duplicate(true)
	_bindings.clear()
	for key in _values:
		setting_changed.emit(key, _values[key])
	if persist:
		save_settings()

func save_settings() -> Error:
	var file := FileAccess.open(storage_path, FileAccess.WRITE)
	if file == null:
		report_error("Could not open settings file for writing")
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"schema_version": SCHEMA_VERSION, "values": _values, "bindings": _bindings}, "  "))
	settings_saved.emit()
	return OK

func load_settings() -> Error:
	if not FileAccess.file_exists(storage_path):
		settings_loaded.emit()
		return OK
	var file := FileAccess.open(storage_path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	if file.get_length() > MAX_SETTINGS_FILE_BYTES:
		file.close()
		report_error("Settings file exceeds the safe size limit")
		return ERR_FILE_CORRUPT
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary or int(parsed.get("schema_version", 0)) > SCHEMA_VERSION:
		report_error("Settings file is invalid or from a newer schema")
		return ERR_FILE_CORRUPT
	var loaded_values = parsed.get("values", {})
	if not loaded_values is Dictionary:
		report_error("Settings values are invalid")
		return ERR_FILE_CORRUPT
	for key in loaded_values:
		if DEFAULTS.has(StringName(key)):
			var setting_key := StringName(key)
			_values[setting_key] = _sanitize_known_setting(setting_key, loaded_values[key])
	var loaded_bindings = parsed.get("bindings", {})
	_bindings = loaded_bindings.duplicate(true) if loaded_bindings is Dictionary else {}
	settings_loaded.emit()
	return OK

func _sanitize_known_setting(key: StringName, value: Variant) -> Variant:
	if not DEFAULTS.has(key):
		return value
	var fallback: Variant = DEFAULTS[key]
	if NUMERIC_RANGES.has(key):
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
			return fallback
		var bounds: Vector2 = NUMERIC_RANGES[key]
		return clampf(float(value), bounds.x, bounds.y)
	if key == &"frame_rate_limit":
		return clampi(int(value), 0, 1000) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else fallback
	if STRING_OPTIONS.has(key):
		if typeof(value) not in [TYPE_STRING, TYPE_STRING_NAME]:
			return fallback
		var normalized := String(value).to_lower()
		return normalized if normalized in STRING_OPTIONS[key] else fallback
	if fallback is bool:
		return value if value is bool else fallback
	if fallback is Dictionary:
		if not value is Dictionary:
			return fallback.duplicate(true)
		var sanitized: Dictionary = fallback.duplicate(true)
		for nested_key in sanitized:
			if value.has(nested_key) and value[nested_key] is bool:
				sanitized[nested_key] = value[nested_key]
		return sanitized
	return value if typeof(value) == typeof(fallback) else fallback

func snapshot() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "values": _values.duplicate(true), "bindings": _bindings.duplicate(true)}
