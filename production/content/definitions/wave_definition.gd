class_name WaveDefinition
extends ContentDefinition

@export var start_trigger: StringName = &"immediate"
@export var formation: FormationDefinition
@export var enemy_ids: Array[StringName] = []
@export var spawn_points: Array[Vector2] = []
@export var spawn_delay := 0.1
@export var completion_rule: StringName = &"defeat_all"
@export var timeout := 30.0
@export var objective_ids: Array[StringName] = []
@export var next_wave_condition: StringName = &"complete"
@export var reward_hooks: Array[Dictionary] = []

func get_content_type() -> StringName:
	return &"wave"

func validate_definition() -> PackedStringArray:
	var errors := super()
	if formation == null and enemy_ids.is_empty(): errors.append("%s needs a formation or enemy list" % stable_id)
	if completion_rule not in [&"defeat_all", &"survive", &"timeout", &"objective"]: errors.append("%s has invalid completion rule" % stable_id)
	if timeout <= 0.0 or spawn_delay < 0.0: errors.append("%s has invalid timing" % stable_id)
	return errors
