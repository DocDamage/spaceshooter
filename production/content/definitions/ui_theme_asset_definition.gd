class_name UIThemeAssetDefinition
extends ContentDefinition

@export_file("*.png", "*.webp") var visual_asset_path := ""
@export var asset_role: StringName = &"panel"
@export var nine_patch_margins := Vector4i.ZERO

func get_content_type() -> StringName:
	return &"ui_theme_asset"
