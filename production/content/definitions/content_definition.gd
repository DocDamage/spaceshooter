class_name ContentDefinition
extends Resource

@export var stable_id: StringName
@export var display_name := ""
@export var dependency_ids: Array[StringName] = []
@export var content_version := "1"

func get_content_type() -> StringName:
	return &"content"

func validate_definition() -> PackedStringArray:
	var errors := PackedStringArray()
	if stable_id.is_empty():
		errors.append("stable_id is required")
	if content_version.is_empty():
		errors.append("content_version is required for %s" % stable_id)
	return errors
