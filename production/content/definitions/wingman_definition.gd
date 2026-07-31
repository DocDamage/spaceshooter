class_name WingmanDefinition
extends ContentDefinition

@export var pilot_id: StringName
@export var ship_id: StringName
@export var ai_profile: Dictionary = {}
@export var basic_attack_id: StringName
@export var special_ability_id: StringName
@export_range(0.0, 120.0) var command_cooldown := 1.0
@export_range(0.0, 120.0) var special_cooldown := 12.0
@export var dialogue_profile: StringName
@export var unlock_flags: Dictionary = {}

func get_content_type() -> StringName:
	return &"wingman"

func validate_definition() -> PackedStringArray:
	var errors := super()
	if pilot_id.is_empty(): errors.append("%s requires a pilot" % stable_id)
	if ship_id.is_empty(): errors.append("%s requires a ship" % stable_id)
	return errors
