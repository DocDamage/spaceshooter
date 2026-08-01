class_name ProjectileDefinition
extends ContentDefinition

enum HitBehavior { DESPAWN, PIERCE, BOUNCE, DETONATE, STICK, PHASE }
enum DespawnBehavior { SILENT, IMPACT, EXPLODE, SPLIT }

@export_file("*.png", "*.webp") var visual_asset_path := ""
@export var collision_radius := 6.0
@export var speed := 600.0
@export var acceleration := 0.0
@export var lifetime_seconds := 5.0
@export var damage := 10.0
@export var team: StringName = &"neutral"
@export var pierce_count := 0
@export var bounce_count := 0
@export var homing_strength := 0.0
@export var turn_rate_degrees := 0.0
@export var hit_behavior: HitBehavior = HitBehavior.DESPAWN
@export var despawn_behavior: DespawnBehavior = DespawnBehavior.IMPACT
@export var interaction_tags: Array[StringName] = []
@export var graze_value := 1
@export var cancel_class: StringName = &"none"
@export var flux_value := 1
@export var allow_regraze := false
@export var trail_effect_id: StringName
@export var impact_effect_id: StringName
@export var audio_event_id: StringName
@export var pool_category: StringName = &"player_bullet"

func get_content_type() -> StringName:
	return &"projectile"

func validate_definition() -> PackedStringArray:
	var errors := super.validate_definition()
	if collision_radius <= 0.0:
		errors.append("collision_radius must be positive for %s" % stable_id)
	if speed < 0.0 or lifetime_seconds <= 0.0:
		errors.append("speed cannot be negative and lifetime must be positive for %s" % stable_id)
	if damage < 0.0 or pierce_count < 0 or bounce_count < 0 or graze_value < 0 or flux_value < 0:
		errors.append("damage and interaction counts cannot be negative for %s" % stable_id)
	if cancel_class not in [&"none", &"eligible", &"protected"]:
		errors.append("cancel_class must be none, eligible, or protected for %s" % stable_id)
	if pool_category.is_empty():
		errors.append("pool_category is required for %s" % stable_id)
	return errors
