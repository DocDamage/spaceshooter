class_name AttackDeckDefinition
extends ContentDefinition

@export var attack_patterns: Array[AttackPatternDefinition] = []
@export var selection_mode: StringName = &"sequential"
@export var minimum_distance := 0.0
@export var maximum_distance := 9999.0
@export var maximum_health_ratio := 1.0
@export var minimum_difficulty := 0
@export var minimum_player_count := 1
@export var elite_only := false

func get_content_type() -> StringName:
	return &"attack_deck"

func validate_definition() -> PackedStringArray:
	var errors := super()
	if attack_patterns.is_empty(): errors.append("%s requires at least one attack pattern" % stable_id)
	if selection_mode not in [&"sequential", &"random", &"distance"]: errors.append("%s has unsupported selection_mode" % stable_id)
	return errors
