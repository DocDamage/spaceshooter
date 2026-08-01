class_name MovementPatternDefinition
extends ContentDefinition

enum Pattern { STRAIGHT, SINE, ZIGZAG, FORMATION_FOLLOW, DIVE, CHASE, FLANK, ORBIT, GUARD, STOP_AND_FIRE, CROSS_SCREEN, RETREAT, AMBUSH, TELEPORT, CARRIER_PATH, BOSS_ANCHOR }

@export var pattern := Pattern.STRAIGHT
@export var speed := 90.0
@export var amplitude := 80.0
@export var frequency := 1.0
@export var delay := 0.0
@export var duration := 5.0
@export var target_offset := Vector2.ZERO
@export var arena_margin := 24.0
@export var path: MovementPathDefinition

func get_content_type() -> StringName:
	return &"movement_pattern"

func validate_definition() -> PackedStringArray:
	var errors := super()
	if speed < 0.0 or frequency < 0.0 or duration < 0.0 or arena_margin < 0.0:
		errors.append("%s has invalid movement parameters" % stable_id)
	return errors
