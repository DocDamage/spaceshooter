class_name StatCalculator
extends RefCounted

const DEFAULT_CAPS := {"max_health": 9999.0, "shield": 9999.0, "armor": 500.0, "move_speed": 1200.0, "damage": 20.0, "fire_rate": 10.0, "status_chance": 1.0}

static func calculate(base_stats: Dictionary, allocated: Dictionary = {}, equipment: Array[Dictionary] = [], skills: Array[Dictionary] = [], temporary: Array[Dictionary] = [], statuses: Array[Dictionary] = [], difficulty: Dictionary = {}, caps: Dictionary = {}) -> Dictionary:
	var result := base_stats.duplicate(true)
	_apply_additive(result, _allocation_modifiers(allocated))
	for source in equipment: _apply_additive(result, source)
	for source in skills: _apply_additive(result, source)
	for source in temporary: _apply_additive(result, source)
	for source in statuses: _apply_additive(result, source)
	for key in difficulty:
		if String(key).ends_with("_multiplier"):
			var stat_key := StringName(String(key).trim_suffix("_multiplier"))
			result[stat_key] = float(result.get(stat_key, 0.0)) * float(difficulty[key])
	var active_caps := DEFAULT_CAPS.duplicate()
	active_caps.merge(caps, true)
	for key in result:
		if active_caps.has(key): result[key] = clampf(float(result[key]), 0.0, float(active_caps[key]))
	return result

static func equipment_delta(base_stats: Dictionary, current_modifiers: Array[Dictionary], candidate: Dictionary, replaced: Dictionary = {}) -> Dictionary:
	var before := calculate(base_stats, {}, current_modifiers)
	var after_sources := current_modifiers.duplicate(true)
	if not replaced.is_empty(): after_sources.erase(replaced)
	after_sources.append(candidate)
	var after := calculate(base_stats, {}, after_sources)
	var delta := {}
	for key in before:
		delta[key] = float(after.get(key, 0.0)) - float(before[key])
	for key in after:
		if not delta.has(key): delta[key] = float(after[key])
	return delta

static func _allocation_modifiers(allocated: Dictionary) -> Dictionary:
	return {"max_health": float(allocated.get(&"hull", 0)) * 5.0, "shield": float(allocated.get(&"shield", 0)) * 3.0,
		"damage": float(allocated.get(&"power", 0)) * 0.02, "move_speed": float(allocated.get(&"mobility", 0)) * 2.0}

static func _apply_additive(target: Dictionary, modifiers: Dictionary) -> void:
	for key in modifiers:
		target[key] = float(target.get(key, 0.0)) + float(modifiers[key])
