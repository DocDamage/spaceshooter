class_name PilotDefinition
extends ContentDefinition

@export var portrait_id: StringName
@export_multiline var biography := ""
@export var voice_style := "neutral"
@export var dialogue_profile: StringName
@export var relationships: Dictionary = {}
@export var campaign_perspective: StringName = &"neutral"
@export var unlock_flags: Dictionary = {}

func get_content_type() -> StringName:
	return &"pilot"

func validate_definition() -> PackedStringArray:
	var errors := super()
	if biography.is_empty(): errors.append("%s requires a biography" % stable_id)
	return errors
