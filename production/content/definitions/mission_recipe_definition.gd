class_name MissionRecipeDefinition
extends ContentDefinition

@export var required_sequence: Array[StageSegmentDefinition] = []
@export var optional_pool: Array[StageSegmentDefinition] = []
@export var branch_pool: Array[StageSegmentDefinition] = []
@export_range(0, 8, 1) var branch_count := 0
@export_range(1, 64, 1) var minimum_segment_count := 5
@export_range(1, 64, 1) var maximum_segment_count := 12
@export_range(1, 8, 1) var repetition_limit := 1
@export var required_checkpoint_order: Array[StringName] = [&"midpoint", &"pre_boss"]
@export var allowed_factions: Array[StringName] = []
@export var required_objective_types: Array[StringName] = []
@export var allow_secrets := true
@export_range(0, 100, 1) var minimum_difficulty := 0
@export_range(0, 100, 1) var maximum_difficulty := 100

func get_content_type() -> StringName:
	return &"mission_recipe"

func validate_definition() -> PackedStringArray:
	var errors := super()
	if required_sequence.is_empty(): errors.append("%s requires an authored sequence" % stable_id)
	if minimum_segment_count > maximum_segment_count: errors.append("%s has invalid segment count bounds" % stable_id)
	if minimum_difficulty > maximum_difficulty: errors.append("%s has invalid difficulty bounds" % stable_id)
	if branch_count > 0 and branch_pool.is_empty(): errors.append("%s requires branch candidates" % stable_id)
	for segment in required_sequence + optional_pool + branch_pool:
		if segment == null: errors.append("%s contains a null segment" % stable_id)
	return errors
