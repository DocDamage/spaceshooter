class_name ShipPresentation
extends Node2D

var thrust := 0.0
var shield_ratio := 0.0
var health_ratio := 1.0
var recoil := 0.0
var super_active := false
var glow_strength := 1.0
var ship_texture: Texture2D
var shield_texture: Texture2D
var visual_scale := 1.0
var visual_tint := Color.WHITE
var hitbox_radius := 4.5
var graze_radius := 28.0
var focus_active := false
var always_show_hitbox := false

func configure_visual(asset_path: String, scale_factor := 1.0, tint := Color.WHITE) -> void:
	ship_texture = load(asset_path) as Texture2D if not asset_path.is_empty() and ResourceLoader.exists(asset_path) else null
	shield_texture = load("res://assets_runtime/effects/effect_shield_final.png") as Texture2D if ResourceLoader.exists("res://assets_runtime/effects/effect_shield_final.png") else null
	visual_scale = maxf(0.01, scale_factor)
	visual_tint = tint
	queue_redraw()

func configure_arcade_feedback(damage_radius: float, graze_ring_radius: float) -> void:
	hitbox_radius = maxf(0.5, damage_radius)
	graze_radius = maxf(hitbox_radius, graze_ring_radius)
	queue_redraw()

func update_state(move_input: Vector2, shield: float, health: float, firing: bool, super_mode: bool, focused: bool, show_hitbox: bool, delta: float) -> void:
	thrust = move_toward(thrust, clampf(0.45 - move_input.y * 0.45, 0.15, 1.0), delta * 4.0)
	shield_ratio = clampf(shield, 0.0, 1.0); health_ratio = clampf(health, 0.0, 1.0); super_active = super_mode
	focus_active = focused; always_show_hitbox = show_hitbox
	recoil = move_toward(recoil, 1.0 if firing else 0.0, delta * 10.0)
	queue_redraw()

func _draw() -> void:
	var glow := Color("7ef4ff") if not super_active else Color("ffe06d")
	draw_circle(Vector2(-8, 19), 3.0 + thrust * 4.0, Color(glow, 0.35 + thrust * 0.45))
	draw_circle(Vector2(8, 19), 3.0 + thrust * 4.0, Color(glow, 0.35 + thrust * 0.45))
	if ship_texture != null:
		var size := ship_texture.get_size() * visual_scale
		var tint := visual_tint.lerp(Color("ffe06d"), 0.35) if super_active else visual_tint
		draw_texture_rect(ship_texture, Rect2(-size * 0.5 + Vector2(0.0, recoil * 2.0), size), false, tint)
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(0, -25 + recoil * 2.0), Vector2(18, 20), Vector2(0, 12), Vector2(-18, 20)]), Color("6de6ff") if not super_active else Color("ffe06d"))
		draw_circle(Vector2.ZERO, 4.0, Color.WHITE)
	if shield_ratio > 0.01:
		if shield_texture != null:
			draw_texture_rect(shield_texture, Rect2(-32, -32, 64, 64), false, Color(0.45, 0.9, 1.0, shield_ratio * 0.58))
		else:
			draw_arc(Vector2.ZERO, 27.0, -PI, PI, 48, Color(0.3, 0.8, 1.0, shield_ratio * 0.55), 2.0)
	if health_ratio < 0.35:
		for index in 3: draw_circle(Vector2(-5 + index * 5, -12 - index * 6), 2.0 + index, Color(0.3, 0.32, 0.38, 0.45))
	if focus_active or always_show_hitbox:
		draw_arc(Vector2.ZERO, graze_radius, 0.0, TAU, 48, Color(0.45, 0.95, 1.0, 0.18), 1.0)
		draw_circle(Vector2.ZERO, hitbox_radius, Color(1.0, 1.0, 1.0, 0.85))
		draw_arc(Vector2.ZERO, hitbox_radius + 1.0, 0.0, TAU, 24, Color("54eaff"), 1.0)
