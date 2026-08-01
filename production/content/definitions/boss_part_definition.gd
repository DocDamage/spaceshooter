class_name BossPartDefinition
extends ContentDefinition

enum PartType { TURRET, ENGINE, SHIELD, ARMOR_PLATE, GENERATOR, WEAPON_POD }

@export var part_type := PartType.TURRET
@export var maximum_health := 100.0
@export var armor := 0.0
@export var target_offset := Vector2.ZERO
@export var hit_radius := 20.0
@export var active_phase_ids: Array[StringName] = []
@export var removed_attack_ids: Array[StringName] = []
@export var exposes_weakness_multiplier := 1.0
@export var movement_multiplier_after_destroyed := 1.0
@export var retaliation_attack_id: StringName
@export var reward_bonus: Dictionary = {}
@export var challenge_tag: StringName

func get_content_type() -> StringName:
	return &"boss_part"

func validate_definition() -> PackedStringArray:
	var errors := super()
	if maximum_health <= 0.0 or armor < 0.0 or hit_radius <= 0.0:
		errors.append("%s has invalid boss-part durability" % stable_id)
	if exposes_weakness_multiplier < 1.0 or movement_multiplier_after_destroyed < 0.0:
		errors.append("%s has invalid destruction modifiers" % stable_id)
	return errors
