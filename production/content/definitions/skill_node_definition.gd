class_name SkillNodeDefinition
extends ContentDefinition

@export var tree: StringName = &"weapons"
@export_multiline var description := ""
@export_range(1, 99) var cost := 1
@export var prerequisite_id: StringName
@export var prerequisite_rank := 1
@export var exclusive_group: StringName
@export var effects: Dictionary = {}
@export_range(1, 99) var maximum_rank := 1
@export var required_level := 1
@export var required_unlock: StringName

func get_content_type() -> StringName:
	return &"skill_node"

func validate_definition() -> PackedStringArray:
	var errors := super.validate_definition()
	if tree not in [&"weapons", &"defense", &"mobility", &"systems", &"command"]: errors.append("invalid skill tree for %s" % stable_id)
	if cost < 1 or maximum_rank < 1 or required_level < 1: errors.append("invalid skill rank requirements for %s" % stable_id)
	if not prerequisite_id.is_empty() and prerequisite_id == stable_id: errors.append("skill cannot require itself: %s" % stable_id)
	return errors
