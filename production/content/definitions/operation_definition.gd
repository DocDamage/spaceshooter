class_name OperationDefinition
extends ContentDefinition

@export_range(1, 6, 1) var operation_index := 1
@export var theme := ""
@export var environment_tags: Array[StringName] = []
@export var faction_ids: Array[StringName] = []
@export var enemy_roster_ids: Array[StringName] = []
@export var stage_ids: Array[StringName] = []
@export var campaign_node_ids: Array[StringName] = []
@export var miniboss_ids: Array[StringName] = []
@export var operation_boss_id: StringName
@export var stage_mechanics: Dictionary = {}
@export var story_beats: Dictionary = {}
@export var unlocks_by_stage: Dictionary = {}
@export var economy_targets: Dictionary = {}
@export var review_seeds: Dictionary = {}
@export var segment_usage_targets: Dictionary = {}
@export var secret_route_stages: Array[int] = []
@export var validation_plan: Dictionary = {}
@export var production_batches: Dictionary = {}
@export var next_operation_node_id: StringName

func get_content_type() -> StringName:
	return &"operation"

func validate_definition() -> PackedStringArray:
	var errors := super.validate_definition()
	if theme.is_empty(): errors.append("%s requires an operation theme" % stable_id)
	if stage_ids.size() != 10: errors.append("%s requires exactly ten stages" % stable_id)
	if campaign_node_ids.size() != stage_ids.size(): errors.append("%s requires one campaign node per stage" % stable_id)
	if not miniboss_ids.is_empty() and miniboss_ids.size() != stage_ids.size(): errors.append("%s requires one miniboss plan per stage" % stable_id)
	if not production_batches.is_empty() and (production_batches.get("proof", []).size() != 3 or production_batches.get("mid", []).size() != 4 or production_batches.get("finale", []).size() != 3): errors.append("%s has an invalid proof/mid/finale production cycle" % stable_id)
	for stage_number in range(1, stage_ids.size() + 1):
		if not stage_mechanics.has(stage_number): errors.append("%s is missing the Stage %d mechanic" % [stable_id, stage_number])
		if not review_seeds.has(stage_number): errors.append("%s is missing the Stage %d review seeds" % [stable_id, stage_number])
	return errors
