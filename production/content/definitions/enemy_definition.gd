class_name EnemyDefinition
extends ContentDefinition

@export_file("*.png", "*.webp") var visual_asset_path := ""
@export var visual_scale := 1.0
@export var collision_scale := 1.0
@export var visual_anchor := Vector2(0.5, 0.5)
@export var max_health := 40
@export var move_speed := 90.0
@export var armor := 0.0
@export var shield_capacity := 0.0
@export var reward_credits := 10
@export var reward_score := 100
@export var reward_experience := 5
@export var movement_pattern: MovementPatternDefinition
@export var attack_deck: AttackDeckDefinition
@export var drop_table: DropTableDefinition
@export var elite_profile: EliteProfileDefinition
@export var collision_radius := 18.0
@export var visual_tint := Color.WHITE

func get_content_type() -> StringName:
	return &"enemy"

func validate_definition() -> PackedStringArray:
	var errors := super()
	if max_health < 1 or move_speed < 0.0 or collision_radius <= 0.0:
		errors.append("%s has invalid enemy stats" % stable_id)
	return errors
