class_name EnemyVisualFamilyDefinition
extends ContentDefinition

@export_file("*.png", "*.webp") var visual_asset_path := ""
@export var visual_scale := 1.0
@export var muzzle_offset := Vector2.ZERO
@export var explosion_scale := 1.0
@export var faction_tag: StringName = &"raider"
@export var presentation_tags: Array[StringName] = []

func get_content_type() -> StringName:
	return &"enemy_visual_family"

func validate_definition() -> PackedStringArray:
	var errors := super.validate_definition()
	if visual_scale <= 0.0 or explosion_scale <= 0.0: errors.append("%s has invalid visual scale" % stable_id)
	return errors
