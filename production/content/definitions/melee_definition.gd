class_name MeleeDefinition
extends ContentDefinition

@export var damage := 40.0
@export var arc_degrees := 100.0
@export var range_pixels := 80.0
@export var cooldown_seconds := 0.5
@export var shockwave_radius := 0.0
@export var parry_window_seconds := 0.12
@export var hit_stop_seconds := 0.04
@export var close_range_bonus := 0.25
@export var ram_damage_multiplier := 1.5
@export var collision_armor := 0.25

func get_content_type() -> StringName:
	return &"melee"
