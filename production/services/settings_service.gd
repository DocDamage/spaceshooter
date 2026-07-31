class_name SettingsService
extends BaseGameService

signal setting_changed(key: StringName, value: Variant)
signal settings_loaded
signal settings_saved

const SETTINGS_PATH := "user://settings_v1.json"
const SCHEMA_VERSION := 1

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
	&"diagnostics_visible": true,
	&"locale": "en",
	&"controller_dead_zone": 0.25,
	&"aim_sensitivity": 1.0,
	&"movement_sensitivity": 1.0,
	&"analog_movement": true,
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
	if _values.get(key) == value:
		return
	_values[key] = value
	setting_changed.emit(key, value)
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
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or int(parsed.get("schema_version", 0)) > SCHEMA_VERSION:
		report_error("Settings file is invalid or from a newer schema")
		return ERR_FILE_CORRUPT
	var loaded_values: Dictionary = parsed.get("values", {})
	for key in loaded_values:
		if DEFAULTS.has(StringName(key)):
			_values[StringName(key)] = loaded_values[key]
	_bindings = parsed.get("bindings", {}).duplicate(true)
	settings_loaded.emit()
	return OK

func snapshot() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "values": _values.duplicate(true), "bindings": _bindings.duplicate(true)}
