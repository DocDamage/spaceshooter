class_name EnemyArchetypeDefinition
extends ContentDefinition

enum Role { POPCORN, STREAMER, FAN_TURRET, SWEEPER, ANCHOR, FLANKER }

@export var role: Role = Role.POPCORN
@export var target_priority := 1
@export var conversion_marker := false
@export var pressure_cost := 1

func get_content_type() -> StringName:
	return &"enemy_archetype"

func role_name() -> StringName:
	return ["popcorn", "streamer", "fan_turret", "sweeper", "anchor", "flanker"][role]

func validate_definition() -> PackedStringArray:
	var errors := super.validate_definition()
	if target_priority < 0 or pressure_cost < 1: errors.append("%s has invalid combat weighting" % stable_id)
	return errors
