class_name BackgroundLayerDefinition
extends ContentDefinition

@export_file("*.png", "*.webp") var visual_asset_path := ""
@export var scroll_ratio := Vector2(0.0, 0.25)
@export var repeat_x := true
@export var repeat_y := true
@export var screen_layer: StringName = &"background_far"
@export var pseudo_altitude: StringName = &"far"
@export_enum("far_background", "middle_background", "near_background", "foreground_flyover", "particles", "environment_lighting") var presentation_layer := "far_background"
@export_enum("wrap", "clamp", "once") var loop_behavior := "wrap"
@export_enum("crossfade", "slide", "cut") var transition_behavior := "crossfade"
@export var reduced_motion_scroll_ratio := Vector2(0.0, 0.02)
@export var loop_size := Vector2(540.0, 960.0)
@export var environment_tags: Array[StringName] = []
@export_range(-100, 100) var z_order := -20

func get_content_type() -> StringName:
	return &"background_layer"
