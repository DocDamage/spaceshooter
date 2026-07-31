class_name WeaponDefinition
extends ContentDefinition

enum WeaponFamily { PULSE, SPREAD, BEAM, MISSILE, MINE, RAIL, DRONE, SCATTER, HOMING_LASER, CHAIN_LIGHTNING }
enum TriggerMode { AUTOMATIC, SEMI_AUTOMATIC, CHARGE }

@export var family: WeaponFamily = WeaponFamily.PULSE
@export var trigger_mode: TriggerMode = TriggerMode.AUTOMATIC
@export var projectile_definition: ProjectileDefinition
@export var damage := 20.0
@export var projectile_speed := 700.0 # Legacy fallback when no projectile definition is assigned.
@export var cooldown_seconds := 0.16
@export var burst_count := 1
@export var burst_interval := 0.05
@export var minimum_charge_seconds := 0.0
@export var maximum_charge_seconds := 0.0
@export var heat_per_shot := 0.0
@export var maximum_heat := 100.0
@export var heat_dissipation_per_second := 20.0
@export var energy_cost := 0.0
@export var magazine_size := 0
@export var reload_seconds := 0.0
@export var projectile_count := 1
@export var spread_degrees := 0.0
@export var muzzle_offsets: Array[Vector2] = [Vector2.ZERO]
@export var recoil_strength := 0.0
@export_range(1, 99) var maximum_upgrade_level := 10
@export var damage_per_upgrade := 0.1
@export var fire_rate_per_upgrade := 0.03
@export var projectile_count_upgrade_interval := 3
@export var spread_per_upgrade := 0.0
@export var penetration_per_upgrade := 0
@export var status_chance_per_upgrade := 0.01
@export var visual_intensity_per_upgrade := 0.08
@export var status_effect_ids: Array[StringName] = []

func get_content_type() -> StringName:
	return &"weapon"

func validate_definition() -> PackedStringArray:
	var errors := super.validate_definition()
	if damage < 0.0 or cooldown_seconds < 0.0:
		errors.append("damage and cooldown cannot be negative for %s" % stable_id)
	if burst_count < 1 or projectile_count < 1 or muzzle_offsets.is_empty():
		errors.append("weapon requires a burst, projectile, and muzzle point for %s" % stable_id)
	if maximum_heat <= 0.0 or energy_cost < 0.0:
		errors.append("invalid heat or energy configuration for %s" % stable_id)
	return errors
