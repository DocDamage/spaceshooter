class_name TrainingController
extends RefCounted

const OPTIONS := [&"invulnerability", &"infinite_resources", &"damage_numbers", &"hitbox_display"]

var options := {&"invulnerability": false, &"infinite_resources": false, &"damage_numbers": true, &"hitbox_display": false}
var selected_enemy: StringName
var selected_formation: StringName
var selected_boss: StringName
var selected_phase := 0
var speed_scale := 1.0
var reset_count := 0

func set_option(option: StringName, enabled: bool) -> bool:
	if option not in OPTIONS: return false
	options[option] = enabled
	return true

func select_encounter(enemy_id: StringName = &"", formation_id: StringName = &"", boss_id: StringName = &"", phase := 0) -> bool:
	if enemy_id.is_empty() and formation_id.is_empty() and boss_id.is_empty(): return false
	selected_enemy = enemy_id; selected_formation = formation_id; selected_boss = boss_id; selected_phase = maxi(0, phase)
	return true

func set_speed(value: float) -> void:
	speed_scale = clampf(value, 0.1, 2.0)

func projectile_practice_config(interaction: StringName) -> Dictionary:
	return {"interaction": interaction, "invulnerability": options[&"invulnerability"], "infinite_resources": options[&"infinite_resources"], "speed_scale": speed_scale, "rewards_enabled": false}

func reset() -> void:
	reset_count += 1
