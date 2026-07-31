class_name EliteProfileDefinition
extends ContentDefinition

@export var health_multiplier := 1.5
@export var armor_bonus := 0.0
@export var shield_bonus := 0.0
@export var speed_multiplier := 1.1
@export var attack_cadence_multiplier := 1.15
@export var status_ids: Array[StringName] = []
@export var death_effect_id: StringName
@export var drop_table: DropTableDefinition
@export var tint := Color("ffd166")

func get_content_type() -> StringName:
	return &"elite_profile"

func validate_definition() -> PackedStringArray:
	var errors := super()
	if health_multiplier <= 0.0 or speed_multiplier <= 0.0 or attack_cadence_multiplier <= 0.0:
		errors.append("%s multipliers must be positive" % stable_id)
	return errors
