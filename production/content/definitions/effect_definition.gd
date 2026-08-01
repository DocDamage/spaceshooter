class_name EffectDefinition
extends ContentDefinition

@export_file("*.png", "*.webp") var visual_asset_path := ""
@export var frame_size := Vector2i.ZERO
@export var frame_count := 1
@export var columns := 1
@export var playback_fps := 12.0
@export var loops := false
@export var event_frames: Dictionary = {}
@export var damage_flash_compatible := false
@export var destruction_sequence := false

func get_content_type() -> StringName:
	return &"effect"

func validate_definition() -> PackedStringArray:
	var errors := super.validate_definition()
	if frame_count < 1:
		errors.append("frame_count must be at least one for %s" % stable_id)
	if columns < 1:
		errors.append("columns must be at least one for %s" % stable_id)
	if playback_fps <= 0.0:
		errors.append("playback_fps must be positive for %s" % stable_id)
	return errors
