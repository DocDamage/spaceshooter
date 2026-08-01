class_name AttackPhraseDefinition
extends ContentDefinition

@export var pattern: AttackPatternDefinition
@export var novice_pattern: AttackPatternDefinition
@export var expert_pattern: AttackPatternDefinition
@export var telegraph_seconds := 0.25
@export var recovery_seconds := 0.35
@export var expected_gear: StringName = &"either"
@export var safe_lane := Rect2(216, 720, 108, 180)

func get_content_type() -> StringName:
	return &"attack_phrase"

func pattern_for_rating(rating: int) -> AttackPatternDefinition:
	if rating >= 75 and expert_pattern != null: return expert_pattern
	if rating <= 25 and novice_pattern != null: return novice_pattern
	return pattern

func validate_definition() -> PackedStringArray:
	var errors := super.validate_definition()
	if pattern == null or telegraph_seconds < 0.0 or recovery_seconds < 0.0: errors.append("%s needs a pattern and non-negative timings" % stable_id)
	if expected_gear not in [&"normal", &"focus", &"either"]: errors.append("%s has unsupported expected_gear" % stable_id)
	if safe_lane.size.x < 24.0 or safe_lane.size.y <= 0.0: errors.append("%s safe lane is not navigable" % stable_id)
	return errors
