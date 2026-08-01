class_name SecretDefinition
extends ContentDefinition

const TRIGGERS := [&"formation_order", &"chain_threshold", &"hidden_target", &"preserve_target", &"ability", &"branch", &"area", &"objective", &"boss_part"]

@export_enum("formation_order", "chain_threshold", "hidden_target", "preserve_target", "ability", "branch", "area", "objective", "boss_part") var trigger_type := "hidden_target"
@export var trigger_id: StringName
@export var threshold := 1
@export var unlock_segment_id: StringName
@export var reward: Dictionary = {}
@export var dialogue_hook: StringName

func get_content_type() -> StringName:
	return &"secret"

func validate_definition() -> PackedStringArray:
	var errors := super()
	if StringName(trigger_type) not in TRIGGERS: errors.append("%s has an unsupported secret trigger" % stable_id)
	if threshold < 1: errors.append("%s threshold must be positive" % stable_id)
	return errors
