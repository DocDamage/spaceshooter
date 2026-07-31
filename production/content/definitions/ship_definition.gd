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

func get_content_type() -> StringName:
	return &"ship"
