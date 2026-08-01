class_name MovementPathDefinition
extends ContentDefinition

@export var points: PackedVector2Array = []
@export var duration := 1.0
@export var loop := false
@export var curve := 0.0
@export var relative_to_spawn := true

func get_content_type() -> StringName:
	return &"movement_path"

func position_at(progress: float) -> Vector2:
	if points.is_empty(): return Vector2.ZERO
	if points.size() == 1: return points[0]
	var time := fposmod(progress, 1.0) if loop else clampf(progress, 0.0, 1.0)
	if curve != 0.0: time = ease(time, curve)
	var scaled := time * float(points.size() - 1)
	var index := mini(points.size() - 2, floori(scaled))
	return points[index].lerp(points[index + 1], scaled - index)

func validate_definition() -> PackedStringArray:
	var errors := super.validate_definition()
	if points.size() < 2 or duration <= 0.0: errors.append("%s needs two points and positive duration" % stable_id)
	return errors
