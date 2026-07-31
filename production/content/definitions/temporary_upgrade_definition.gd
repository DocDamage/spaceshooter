class_name TemporaryUpgradeDefinition
extends ContentDefinition

@export var rarity: StringName = &"common"
@export var modifiers: Dictionary = {}
@export var tags: Array[StringName] = []
@export var incompatible_tags: Array[StringName] = []
@export_multiline var synergy_hint := ""

func get_content_type() -> StringName:
	return &"temporary_upgrade"

func validate_definition() -> PackedStringArray:
	var errors := super.validate_definition()
	if rarity not in [&"common", &"uncommon", &"rare", &"epic", &"legendary"]: errors.append("invalid temporary upgrade rarity for %s" % stable_id)
	if modifiers.is_empty(): errors.append("temporary upgrade requires modifiers for %s" % stable_id)
	return errors
