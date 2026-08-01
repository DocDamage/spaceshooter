class_name StagePropDefinition
extends ContentDefinition

@export_file("*.png", "*.webp") var visual_asset_path := ""
@export var local_position := Vector2(270, 220)
@export var visual_scale := Vector2.ONE
@export var rotation_degrees := 0.0
@export var tint := Color.WHITE
@export_range(-100, 100, 1) var z_order := -8
@export_enum("far", "middle", "near", "foreground") var depth := "middle"
@export_enum("none", "decorative", "solid", "hazard") var collision_recommendation := "decorative"
@export var presentation_tags: Array[StringName] = []

func get_content_type() -> StringName:
	return &"stage_prop"

func validate_definition() -> PackedStringArray:
	var errors := super.validate_definition()
	if visual_asset_path.is_empty() or not ResourceLoader.exists(visual_asset_path):
		errors.append("%s requires an approved runtime visual" % stable_id)
	if visual_scale.x <= 0.0 or visual_scale.y <= 0.0:
		errors.append("%s has an invalid visual scale" % stable_id)
	return errors
