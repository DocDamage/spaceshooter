class_name ArcadeInputRules
extends RefCounted

static func radial_response(raw: Vector2, dead_zone: float, response_curve: float) -> Vector2:
	var magnitude := raw.length()
	var threshold := clampf(dead_zone, 0.0, 0.95)
	if magnitude <= threshold + 0.00001:
		return Vector2.ZERO
	var normalized := raw / magnitude
	var scaled := inverse_lerp(threshold, 1.0, minf(magnitude, 1.0))
	return normalized * pow(scaled, maxf(0.1, response_curve))

static func select_fire_mode(rapid_pressed: bool, focus_pressed: bool) -> StringName:
	if focus_pressed:
		return &"focus"
	if rapid_pressed:
		return &"rapid"
	return &""
