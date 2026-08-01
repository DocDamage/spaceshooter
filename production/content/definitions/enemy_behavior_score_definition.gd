class_name EnemyBehaviorScoreDefinition
extends ContentDefinition

@export var entry_path: MovementPathDefinition
@export var reposition_path: MovementPathDefinition
@export var exit_path: MovementPathDefinition
@export var phrases: Array[AttackPhraseDefinition] = []

func get_content_type() -> StringName:
	return &"enemy_behavior_score"

func validate_definition() -> PackedStringArray:
	var errors := super.validate_definition()
	if phrases.is_empty(): errors.append("%s needs at least one attack phrase" % stable_id)
	return errors

func fingerprint(seed: int) -> String:
	return EnemyPhraseValidator.fingerprint(self, seed)
