class_name SuperModeDefinition
extends ContentDefinition

@export var charge_required := 100.0
@export var duration_seconds := 8.0
@export var damage_multiplier := 1.5
@export var speed_multiplier := 1.2
@export var invulnerable := false
@export var replacement_weapon: WeaponDefinition
@export var cancel_refund_ratio := 0.0
@export var activation_invulnerability_seconds := 0.45
@export var recovery_seconds := 1.25
@export_range(0, 3) var rank_gain := 1

func get_content_type() -> StringName:
	return &"super_mode"
