class_name AttackPatternDefinition
extends ContentDefinition

enum Pattern { AIMED_BURST, PREDICTIVE_BURST, FIXED_SPREAD, RING, SPIRAL, ALTERNATING_SPREAD, SWEEPING_LASER, MISSILE_VOLLEY, MINE_FIELD, DRONE_RELEASE, CHARGE_SHOT, RADIAL_PULSE, SHOTGUN, WALL_WITH_GAPS }

@export var pattern := Pattern.AIMED_BURST
@export var projectile_count := 1
@export var burst_count := 1
@export var burst_interval := 0.12
@export var spread_degrees := 0.0
@export var projectile_speed := 220.0
@export var damage := 8.0
@export var cooldown := 1.5
@export var gap_count := 1
@export var gap_width := 72.0
@export var telegraph_seconds := 0.25

func get_content_type() -> StringName:
	return &"attack_pattern"

func validate_definition() -> PackedStringArray:
	var errors := super()
	if projectile_count < 1 or burst_count < 1 or cooldown < 0.0 or projectile_speed < 0.0:
		errors.append("%s has invalid attack parameters" % stable_id)
	if pattern == Pattern.WALL_WITH_GAPS and (gap_count < 1 or gap_width < 24.0):
		errors.append("%s wall pattern must provide a navigable gap" % stable_id)
	return errors
