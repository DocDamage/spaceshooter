class_name PresentationActor
extends Node2D

signal targetability_changed(targetable: bool)

@export_range(-1.0, 1.0) var simulated_altitude := 0.0
@export var visual_offset := Vector2.ZERO
@export_range(-1.0, 1.0) var banking_amount := 0.0
@export_range(-1.0, 1.0) var pitch_amount := 0.0
@export var targetable_altitude_range := Vector2(-0.15, 0.15)

var visual_root: Node2D
var shadow: Polygon2D
var settings: SettingsService
var _was_targetable := true

func configure(root: Node2D, settings_service: SettingsService = null) -> void:
	visual_root = root
	settings = settings_service
	if visual_root != null:
		visual_root.top_level = false
	_build_shadow()
	apply_presentation()

func set_altitude(value: float) -> void:
	simulated_altitude = clampf(value, -1.0, 1.0)
	apply_presentation()

func is_targetable() -> bool:
	return simulated_altitude >= targetable_altitude_range.x and simulated_altitude <= targetable_altitude_range.y

func apply_presentation() -> void:
	if visual_root == null: return
	var motion := 1.0 - float(settings.get_setting(&"background_motion_reduction", 0.0)) if settings != null else 1.0
	var depth_scale := lerpf(1.0, 0.55, maxf(0.0, simulated_altitude))
	visual_root.position = visual_offset + Vector2(0.0, simulated_altitude * 72.0 * motion)
	visual_root.scale = Vector2(depth_scale * (1.0 - absf(banking_amount) * 0.18), depth_scale * (1.0 - absf(pitch_amount) * 0.12))
	visual_root.rotation = banking_amount * 0.16 * motion
	if shadow != null:
		shadow.position = Vector2(10.0, 18.0) + Vector2(18.0, 28.0) * simulated_altitude
		shadow.scale = Vector2.ONE * depth_scale
		shadow.modulate.a = clampf(0.32 - absf(simulated_altitude) * 0.18, 0.08, 0.32)
	var targetable := is_targetable()
	visual_root.modulate.a = 1.0 if targetable else 0.58
	if targetable != _was_targetable:
		_was_targetable = targetable
		targetability_changed.emit(targetable)

func _build_shadow() -> void:
	if shadow != null or get_parent() == null: return
	shadow = Polygon2D.new()
	shadow.name = "PresentationShadow"
	shadow.polygon = PackedVector2Array([Vector2(-15, -7), Vector2(15, -7), Vector2(11, 7), Vector2(-11, 7)])
	shadow.color = Color(0.0, 0.0, 0.08, 0.32)
	shadow.z_index = -10
	get_parent().add_child(shadow)
	get_parent().move_child(shadow, 0)
