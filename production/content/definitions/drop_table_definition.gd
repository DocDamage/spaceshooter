class_name DropTableDefinition
extends ContentDefinition

@export var guaranteed_entries: Array[Dictionary] = []
@export var weighted_entries: Array[Dictionary] = []
@export var rolls := 1
@export var pity_after_misses := 0
@export var difficulty_multiplier := 0.0
@export var ownership: StringName = &"source_player"

func get_content_type() -> StringName:
	return &"drop_table"

func validate_definition() -> PackedStringArray:
	var errors := super()
	if rolls < 0: errors.append("%s rolls cannot be negative" % stable_id)
	if ownership not in [&"source_player", &"shared", &"round_robin"]: errors.append("%s has invalid ownership" % stable_id)
	for entry in guaranteed_entries + weighted_entries:
		if StringName(entry.get("category", &"")).is_empty() or int(entry.get("amount", 0)) <= 0:
			errors.append("%s contains an invalid drop entry" % stable_id)
	return errors
