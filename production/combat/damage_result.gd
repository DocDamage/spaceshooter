class_name DamageResult
extends RefCounted

var accepted := false
var blocked_reason: StringName = &""
var input_damage := 0.0
var shield_damage := 0.0
var armor_reduction := 0.0
var resistance_multiplier := 1.0
var health_damage := 0.0
var reflected_damage := 0.0
var absorbed_damage := 0.0
var target_destroyed := false
var applied_statuses: Array[StringName] = []

func snapshot() -> Dictionary:
	return {
		"accepted": accepted, "blocked_reason": blocked_reason, "input_damage": input_damage,
		"shield_damage": shield_damage, "armor_reduction": armor_reduction,
		"resistance_multiplier": resistance_multiplier, "health_damage": health_damage,
		"reflected_damage": reflected_damage, "absorbed_damage": absorbed_damage,
		"target_destroyed": target_destroyed, "applied_statuses": applied_statuses.duplicate()
	}
