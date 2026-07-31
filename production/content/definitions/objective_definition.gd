class_name ObjectiveDefinition
extends ContentDefinition

const TYPES := [&"rescue", &"escort", &"survive", &"destroy_marked", &"protect", &"collect", &"sabotage", &"chain", &"avoid_neutral_damage", &"time_route"]

@export_enum("rescue", "escort", "survive", "destroy_marked", "protect", "collect", "sabotage", "chain", "avoid_neutral_damage", "time_route") var objective_type := "destroy_marked"
@export var start_condition: StringName = &"segment_start"
@export var target_id: StringName
@export_range(1, 9999, 1) var target_count := 1
@export_range(0.0, 3600.0, 0.1) var duration_seconds := 0.0
@export var optional := false
@export var fail_on_neutral_damage := false
@export var reward: Dictionary = {}
@export var dialogue_hooks: Dictionary = {}

func get_content_type() -> StringName:
	return &"objective"

func validate_definition() -> PackedStringArray:
	var errors := super()
	if StringName(objective_type) not in TYPES: errors.append("%s has an unsupported objective type" % stable_id)
	if target_count < 1: errors.append("%s target_count must be positive" % stable_id)
	if objective_type in ["survive", "time_route"] and duration_seconds <= 0.0: errors.append("%s requires a duration" % stable_id)
	return errors
