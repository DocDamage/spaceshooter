class_name DifficultyController
extends RefCounted

const PRESETS := {
	&"story": {"rating": 20, "enemy_health": 0.75, "enemy_damage": 0.65, "projectile_speed": 0.8, "density": 0.75, "drops": 1.35},
	&"normal": {"rating": 50, "enemy_health": 1.0, "enemy_damage": 1.0, "projectile_speed": 1.0, "density": 1.0, "drops": 1.0},
	&"veteran": {"rating": 75, "enemy_health": 1.2, "enemy_damage": 1.25, "projectile_speed": 1.15, "density": 1.2, "drops": 0.9},
	&"nightmare": {"rating": 100, "enemy_health": 1.45, "enemy_damage": 1.6, "projectile_speed": 1.3, "density": 1.4, "drops": 0.8}
}

var preset: StringName = &"normal"
var master_rating := 50
var overrides: Dictionary = {}
var dynamic_enabled := false
var dynamic_offset := 0.0

func configure(preset_id: StringName, rating: int = -1, granular_overrides: Dictionary = {}, dynamic := false) -> bool:
	if not PRESETS.has(preset_id): return false
	preset = preset_id; master_rating = clampi(int(PRESETS[preset].rating) if rating < 0 else rating, 0, 100)
	overrides = granular_overrides.duplicate(true); dynamic_enabled = dynamic; dynamic_offset = 0.0
	return true

func observe_performance(damage_taken_ratio: float, clear_time_ratio: float) -> void:
	if not dynamic_enabled: return
	var target := (0.5 - clampf(damage_taken_ratio, 0.0, 1.0)) * 8.0 + (1.0 - clampf(clear_time_ratio, 0.25, 2.0)) * 4.0
	dynamic_offset = clampf(lerpf(dynamic_offset, target, 0.25), -10.0, 10.0)

func effective(mode: ModeDefinition = null, active_assists: Array[StringName] = []) -> Dictionary:
	var values: Dictionary = PRESETS[preset].duplicate(true)
	var ratio := float(master_rating - int(values.rating)) / 100.0
	for key in [&"enemy_health", &"enemy_damage", &"projectile_speed", &"density"]: values[key] = maxf(0.1, float(values[key]) + ratio)
	for key in overrides: values[key] = overrides[key]
	values.rating = clampi(int(round(master_rating + dynamic_offset)), 0, 100)
	values.dynamic_offset = dynamic_offset; values.active_assists = active_assists.duplicate()
	if mode != null and mode.difficulty_policy == &"standardized": values = PRESETS[&"normal"].duplicate(true)
	# Generation safety is authoritative even when granular overrides are extreme.
	values.projectile_speed = clampf(float(values.get("projectile_speed", 1.0)), 0.5, 1.6)
	values.density = clampf(float(values.get("density", 1.0)), 0.5, 1.75)
	values.enemy_damage = clampf(float(values.get("enemy_damage", 1.0)), 0.25, 2.0)
	return values
