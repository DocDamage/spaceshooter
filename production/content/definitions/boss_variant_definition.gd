class_name BossVariantDefinition
extends ContentDefinition

@export var minimum_new_game_plus_cycle := 1
@export var added_attack_decks: Array[AttackDeckDefinition] = []
@export var replacement_attack_decks: Dictionary = {}
@export var added_parts: Array[BossPartDefinition] = []
@export var removed_part_ids: Array[StringName] = []
@export var additional_summon_ids: Array[StringName] = []
@export var arena_overrides: Dictionary = {}
@export var reward_overrides: Dictionary = {}
@export_range(0.5, 2.0) var cadence_multiplier := 1.0

func get_content_type() -> StringName:
	return &"boss_variant"

func validate_definition() -> PackedStringArray:
	var errors := super()
	if minimum_new_game_plus_cycle < 1: errors.append("%s must target New Game Plus" % stable_id)
	if cadence_multiplier <= 0.0: errors.append("%s has invalid cadence multiplier" % stable_id)
	if added_attack_decks.is_empty() and replacement_attack_decks.is_empty() and added_parts.is_empty() and removed_part_ids.is_empty() and additional_summon_ids.is_empty() and arena_overrides.is_empty():
		errors.append("%s must change behavior, parts, summons, or arena instead of only statistics" % stable_id)
	return errors
