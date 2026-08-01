class_name BossDefinition
extends ContentDefinition

@export var is_miniboss := false
@export var maximum_health := 1000.0
@export var armor := 0.0
@export var shield_capacity := 0.0
@export var phases: Array[BossPhaseDefinition] = []
@export var parts: Array[BossPartDefinition] = []
@export var challenges: Array[BossChallengeDefinition] = []
@export var variants: Array[BossVariantDefinition] = []
@export var guaranteed_rewards: Dictionary = {}
@export var arena_profile: Dictionary = {}
@export var intro_dialogue_id: StringName
@export var defeat_dialogue_id: StringName
@export_file("*.png", "*.webp") var visual_asset_path := ""
@export var visual_scale := 1.0
@export var visual_tint := Color.WHITE
@export var collision_radius := 64.0

func get_content_type() -> StringName:
	return &"boss"

func validate_definition() -> PackedStringArray:
	var errors := super()
	if maximum_health <= 0.0 or armor < 0.0 or shield_capacity < 0.0:
		errors.append("%s has invalid boss durability" % stable_id)
	if visual_scale <= 0.0 or collision_radius <= 0.0: errors.append("%s has invalid boss presentation bounds" % stable_id)
	if phases.is_empty(): errors.append("%s requires at least one phase" % stable_id)
	var previous := 1.01
	for phase in phases:
		if phase == null:
			errors.append("%s contains a null phase" % stable_id)
			continue
		if phase.health_threshold > previous:
			errors.append("%s phase thresholds must be authored in descending order" % stable_id)
		previous = phase.health_threshold
		errors.append_array(phase.validate_definition())
	for part in parts:
		if part != null: errors.append_array(part.validate_definition())
	for challenge in challenges:
		if challenge != null: errors.append_array(challenge.validate_definition())
	for variant in variants:
		if variant != null: errors.append_array(variant.validate_definition())
	return errors
