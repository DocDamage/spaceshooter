class_name CampaignNodeDefinition
extends ContentDefinition

@export var operation_index := 1
@export var stage_index := 1
@export var mission_id: StringName
@export var prerequisite_node_ids: Array[StringName] = []
@export var prerequisite_flags: Dictionary = {}
@export var decision_requirements: Dictionary = {}
@export var secret := false
@export var boss_node := false
@export var practice_boss_ids: Array[StringName] = []
@export var reward_preview: Dictionary = {}
@export var new_game_plus_variant: StringName
@export var map_position := Vector2.ZERO

func get_content_type() -> StringName:
	return &"campaign_node"

func validate_definition() -> PackedStringArray:
	var errors := super()
	if operation_index < 1 or operation_index > 6: errors.append("%s operation must be between 1 and 6" % stable_id)
	if stage_index < 1: errors.append("%s stage index must be positive" % stable_id)
	if mission_id.is_empty(): errors.append("%s requires a mission_id" % stable_id)
	for boss_id in practice_boss_ids:
		if boss_id.is_empty(): errors.append("%s contains an empty practice boss ID" % stable_id)
	return errors
