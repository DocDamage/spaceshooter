class_name PortraitDefinition
extends ContentDefinition

@export_file("*.png", "*.webp") var visual_asset_path := ""
@export var character_id: StringName
@export var expression: StringName = &"neutral"
@export var anchor := Vector2(0.5, 1.0)

func get_content_type() -> StringName:
	return &"portrait"
