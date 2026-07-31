class_name BossPhaseDefinition
extends ContentDefinition

@export_range(0.0, 1.0) var health_threshold := 1.0
@export var maximum_duration := 0.0
@export var transition_condition: StringName = &"health"
@export var movement_patterns: Array[MovementPatternDefinition] = []
@export var attack_decks: Array[AttackDeckDefinition] = []
@export var summon_enemy_ids: Array[StringName] = []
@export var summon_interval := 0.0
@export var maximum_active_summons := 0
@export var arena_behavior: Dictionary = {}
@export var active_part_ids: Array[StringName] = []
@export var music_state: StringName
@export var dialogue_id: StringName
@export var transition_behavior: StringName = &"brief_invulnerability"
@export var enrage_after := 0.0
@export var enrage_attack_deck: AttackDeckDefinition

func get_content_type() -> StringName:
	return &"boss_phase"

func validate_definition() -> PackedStringArray:
	var errors := super()
	if transition_condition not in [&"health", &"duration", &"parts_destroyed", &"external"]:
		errors.append("%s has unsupported phase transition condition" % stable_id)
	if maximum_duration < 0.0 or summon_interval < 0.0 or maximum_active_summons < 0 or enrage_after < 0.0:
		errors.append("%s has invalid phase timing" % stable_id)
	if attack_decks.is_empty(): errors.append("%s requires an attack deck" % stable_id)
	return errors
