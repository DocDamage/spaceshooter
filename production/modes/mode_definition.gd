class_name ModeDefinition
extends RefCounted

var mode_id: StringName
var display_name := ""
var progression_source: StringName = &"standardized"
var allowed_loadouts: StringName = &"player"
var starting_lives := 3
var continue_limit := 0
var score_enabled := true
var checkpoints_enabled := false
var rewards_enabled := false
var stage_selection: StringName = &"fixed_sequence"
var difficulty_policy: StringName = &"selectable"
var seed_policy: StringName = &"fixed"
var multiplayer_allowed := false
var leaderboard_eligible := true
var rules: Dictionary = {}

func _init(id: StringName = &"", title := "") -> void:
	mode_id = id
	display_name = title

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if mode_id.is_empty(): errors.append("mode_id is required")
	if starting_lives < 0: errors.append("starting_lives cannot be negative")
	if continue_limit < -1: errors.append("continue_limit must be -1 (unlimited) or greater")
	if progression_source not in [&"campaign", &"standardized", &"none"]: errors.append("invalid progression source")
	if seed_policy not in [&"random", &"fixed", &"daily", &"weekly", &"player"]: errors.append("invalid seed policy")
	return errors

func snapshot() -> Dictionary:
	return {
		"mode_id": mode_id, "display_name": display_name,
		"progression_source": progression_source, "allowed_loadouts": allowed_loadouts,
		"starting_lives": starting_lives, "continue_limit": continue_limit,
		"score_enabled": score_enabled, "checkpoints_enabled": checkpoints_enabled,
		"rewards_enabled": rewards_enabled, "stage_selection": stage_selection,
		"difficulty_policy": difficulty_policy, "seed_policy": seed_policy,
		"multiplayer_allowed": multiplayer_allowed,
		"leaderboard_eligible": leaderboard_eligible, "rules": rules.duplicate(true)
	}
