class_name EncounterVariantDefinition
extends ContentDefinition

@export var visual_family: EnemyVisualFamilyDefinition
@export var archetype: EnemyArchetypeDefinition
@export var behavior_score: EnemyBehaviorScoreDefinition
@export var difficulty_band: StringName = &"arcade"

func get_content_type() -> StringName:
	return &"encounter_variant"

func validate_definition() -> PackedStringArray:
	var errors := super.validate_definition()
	if visual_family == null or archetype == null or behavior_score == null: errors.append("%s must compose visual, archetype, and behavior" % stable_id)
	if difficulty_band not in [&"novice", &"arcade", &"expert"]: errors.append("%s has invalid difficulty band" % stable_id)
	return errors
