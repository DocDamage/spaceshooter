class_name StageSegmentDefinition
extends ContentDefinition

const CATEGORIES := [&"opening", &"standard_combat", &"formation_combat", &"hazard_field", &"turret_corridor", &"asteroid_field", &"debris_field", &"elite_encounter", &"rescue", &"escort", &"sabotage", &"survival", &"branch", &"secret", &"checkpoint", &"miniboss", &"pre_boss", &"boss", &"exit"]
const CHECKPOINT_KINDS := [&"none", &"midpoint", &"pre_boss"]

@export_enum("opening", "standard_combat", "formation_combat", "hazard_field", "turret_corridor", "asteroid_field", "debris_field", "elite_encounter", "rescue", "escort", "sabotage", "survival", "branch", "secret", "checkpoint", "miniboss", "pre_boss", "boss", "exit") var category := "standard_combat"
@export var entry_connectors: Array[StringName] = [&"main"]
@export var exit_connectors: Array[StringName] = [&"main"]
@export var environment_tags: Array[StringName] = []
@export var faction_ids: Array[StringName] = []
@export var background_layers: Array[BackgroundLayerDefinition] = []
@export var waves: Array[WaveDefinition] = []
@export var hazard_ids: Array[StringName] = []
@export var objectives: Array[ObjectiveDefinition] = []
@export var secrets: Array[SecretDefinition] = []
@export_range(0.0, 600.0, 0.1) var minimum_duration := 0.0
@export_enum("none", "midpoint", "pre_boss") var checkpoint_kind := "none"
@export var safe_spawn_points: Array[Vector2] = [Vector2(270, 820)]
@export var multiplayer_clearance := Rect2(60, 80, 420, 800)
@export_range(1, 10000, 1) var estimated_projectile_budget := 128
@export_range(0, 100, 1) var minimum_difficulty := 0
@export_range(0, 100, 1) var maximum_difficulty := 100
@export var can_terminate_branch := false

func get_content_type() -> StringName:
	return &"stage_segment"

func validate_definition() -> PackedStringArray:
	var errors := super()
	if StringName(category) not in CATEGORIES: errors.append("%s has an invalid segment category" % stable_id)
	if entry_connectors.is_empty(): errors.append("%s requires an entry connector" % stable_id)
	if exit_connectors.is_empty() and not can_terminate_branch and category != "exit": errors.append("%s requires an exit connector" % stable_id)
	if StringName(checkpoint_kind) not in CHECKPOINT_KINDS: errors.append("%s has an invalid checkpoint kind" % stable_id)
	if minimum_difficulty > maximum_difficulty: errors.append("%s has an inverted difficulty range" % stable_id)
	if multiplayer_clearance.size.x < 120.0 or multiplayer_clearance.size.y < 160.0: errors.append("%s has insufficient local multiplayer clearance" % stable_id)
	for point in safe_spawn_points:
		if not multiplayer_clearance.has_point(point): errors.append("%s safe spawn is outside multiplayer clearance" % stable_id)
	return errors

func connects_to(other: StageSegmentDefinition) -> bool:
	if other == null: return false
	for connector in exit_connectors:
		if connector in other.entry_connectors: return true
	return false

func supports_difficulty(value: int) -> bool:
	return value >= minimum_difficulty and value <= maximum_difficulty
