class_name BossChallengeDefinition
extends ContentDefinition

enum ChallengeType { NO_DAMAGE, TIME_LIMIT, CHAIN_THRESHOLD, DESTROY_ALL_PARTS, PRESERVE_TARGET, RESTRICTED_WEAPON, REFLECT_FINAL_ATTACK, NO_SPELL, NO_CONTINUE, SECRET_MECHANIC }

@export var challenge_type := ChallengeType.NO_DAMAGE
@export var target_value := 0.0
@export var allowed_weapon_ids: Array[StringName] = []
@export var required_tag: StringName
@export var reward_overrides: Dictionary = {}
@export var visible := true

func get_content_type() -> StringName:
	return &"boss_challenge"

func validate_definition() -> PackedStringArray:
	var errors := super()
	if challenge_type in [ChallengeType.TIME_LIMIT, ChallengeType.CHAIN_THRESHOLD] and target_value <= 0.0:
		errors.append("%s requires a positive challenge target" % stable_id)
	if challenge_type == ChallengeType.RESTRICTED_WEAPON and allowed_weapon_ids.is_empty():
		errors.append("%s requires at least one allowed weapon" % stable_id)
	return errors
