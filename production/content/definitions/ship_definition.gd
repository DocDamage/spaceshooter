class_name ShipDefinition
extends ContentDefinition

@export_file("*.png", "*.webp") var visual_asset_path := ""
@export var visual_scale := 1.0
@export var collision_scale := 1.0
@export var visual_anchor := Vector2(0.5, 0.5)
@export var max_health := 100
@export var move_speed := 320.0
@export var armor := 4.0
@export var shield_capacity := 40.0
@export var shield_recharge_delay := 2.0
@export var shield_recharge_rate := 12.0
@export var default_weapon_id: StringName

@export_category("Arcade Controls")
@export var normal_speed := 320.0
@export var focus_speed := 160.0
@export_range(3.5, 5.0, 0.1) var hitbox_radius := 4.5
@export_range(24.0, 32.0, 1.0) var graze_radius := 28.0
@export var shot_pattern_id: StringName
@export var focus_pattern_id: StringName = &"weapon.beam"
@export var element_slot_id: StringName = &"spell.aegis"
@export var regulation_controls := true

func get_content_type() -> StringName:
	return &"ship"

func arcade_normal_speed() -> float:
	return normal_speed if normal_speed > 0.0 else move_speed

func arcade_focus_speed() -> float:
	return focus_speed if focus_speed > 0.0 else arcade_normal_speed() * 0.5
