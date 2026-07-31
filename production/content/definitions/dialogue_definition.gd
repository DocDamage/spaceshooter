class_name DialogueDefinition
extends ContentDefinition

const CONTEXTS := [&"briefing", &"hub", &"stage_entry", &"combat", &"objective", &"checkpoint", &"pre_miniboss", &"post_miniboss", &"pre_boss", &"post_boss", &"results", &"codex_unlock"]

@export_enum("briefing", "hub", "stage_entry", "combat", "objective", "checkpoint", "pre_miniboss", "post_miniboss", "pre_boss", "post_boss", "results", "codex_unlock") var context: String = "hub"
@export var lines: Array[Dictionary] = []
@export var one_shot := false
@export var pause_gameplay := false
@export var priority := 0
@export var objective_instruction := false

func get_content_type() -> StringName:
	return &"dialogue"

func validate_definition() -> PackedStringArray:
	var errors := super()
	if StringName(context) not in CONTEXTS: errors.append("%s has an invalid dialogue context" % stable_id)
	if lines.is_empty(): errors.append("%s requires at least one dialogue line" % stable_id)
	return errors
