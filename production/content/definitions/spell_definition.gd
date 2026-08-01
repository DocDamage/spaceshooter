class_name SpellDefinition
extends ContentDefinition

enum School { NOVA, AEGIS, GRAVITY, WARP, VOID, SOLAR, CRYO, STORM, SUMMON, REPAIR }
enum ElementRole { ATTACK, CONTROL, DEFENSE }

@export var school: School = School.NOVA
@export var element_role: ElementRole = ElementRole.ATTACK
@export var energy_cost := 25.0
@export var cooldown_seconds := 5.0
@export var duration_seconds := 0.0
@export var power := 1.0
@export var radius := 160.0
@export var interaction_policy: ProjectileInteractionPolicy
@export var summon_scene: PackedScene
@export_range(1, 99) var maximum_upgrade_level := 10
@export var power_per_upgrade := 0.10
@export var cooldown_reduction_per_upgrade := 0.025

func get_content_type() -> StringName:
	return &"spell"

func validate_definition() -> PackedStringArray:
	var errors := super.validate_definition()
	if energy_cost < 0.0 or cooldown_seconds < 0.0 or duration_seconds < 0.0 or radius < 0.0:
		errors.append("spell timing, energy, and radius cannot be negative for %s" % stable_id)
	return errors
