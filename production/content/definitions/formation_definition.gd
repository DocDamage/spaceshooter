class_name FormationDefinition
extends ContentDefinition

@export var slots: Array[Vector2] = []
@export var leader_slot := 0
@export var member_enemy_ids: Array[StringName] = []
@export var movement_pattern: MovementPatternDefinition
@export var loss_behavior: StringName = &"hold"
@export var ordered_kill_slots: Array[int] = []
@export var ordered_kill_reward := 0
@export var completion_bonus := 0
@export var escape_seconds := 12.0
@export var multiplayer_spacing := 24.0
@export var difficulty_substitutions: Dictionary = {}

func get_content_type() -> StringName:
	return &"formation"

func validate_definition() -> PackedStringArray:
	var errors := super()
	if slots.is_empty(): errors.append("%s requires slots" % stable_id)
	if leader_slot < 0 or leader_slot >= slots.size(): errors.append("%s leader_slot is out of range" % stable_id)
	if not member_enemy_ids.is_empty() and member_enemy_ids.size() != slots.size(): errors.append("%s member count must match slot count" % stable_id)
	if loss_behavior not in [&"hold", &"collapse", &"promote", &"break"]: errors.append("%s has invalid loss behavior" % stable_id)
	return errors
