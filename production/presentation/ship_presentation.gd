class_name ShipPresentation
extends Node2D

var thrust := 0.0
var shield_ratio := 0.0
var health_ratio := 1.0
var recoil := 0.0
var super_active := false
var glow_strength := 1.0

func update_state(move_input: Vector2, shield: float, health: float, firing: bool, super_mode: bool, delta: float) -> void:
	thrust = move_toward(thrust, clampf(0.45 - move_input.y * 0.45, 0.15, 1.0), delta * 4.0)
	shield_ratio = clampf(shield, 0.0, 1.0); health_ratio = clampf(health, 0.0, 1.0); super_active = super_mode
	recoil = move_toward(recoil, 1.0 if firing else 0.0, delta * 10.0)
	queue_redraw()

func _draw() -> void:
	var glow := Color("7ef4ff") if not super_active else Color("ffe06d")
	draw_circle(Vector2(-8, 19), 3.0 + thrust * 4.0, Color(glow, 0.35 + thrust * 0.45))
	draw_circle(Vector2(8, 19), 3.0 + thrust * 4.0, Color(glow, 0.35 + thrust * 0.45))
	draw_colored_polygon(PackedVector2Array([Vector2(0, -25 + recoil * 2.0), Vector2(18, 20), Vector2(0, 12), Vector2(-18, 20)]), Color("6de6ff") if not super_active else Color("ffe06d"))
	draw_circle(Vector2.ZERO, 4.0, Color.WHITE)
	if shield_ratio > 0.01: draw_arc(Vector2.ZERO, 27.0, -PI, PI, 48, Color(0.3, 0.8, 1.0, shield_ratio * 0.55), 2.0)
	if health_ratio < 0.35:
		for index in 3: draw_circle(Vector2(-5 + index * 5, -12 - index * 6), 2.0 + index, Color(0.3, 0.32, 0.38, 0.45))
