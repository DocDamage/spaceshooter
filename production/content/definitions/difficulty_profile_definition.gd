class_name DifficultyProfileDefinition
extends ContentDefinition

@export_range(0, 100) var rating := 50
@export var health_multiplier := 1.0
@export var shield_multiplier := 1.0
@export var speed_multiplier := 1.0
@export var attack_cadence_multiplier := 1.0
@export var projectile_speed_multiplier := 1.0
@export var drop_multiplier := 1.0
@export var elite_substitution_chance := 0.0
@export var added_attack_ids: Array[StringName] = []

func get_content_type() -> StringName:
	return &"difficulty_profile"
