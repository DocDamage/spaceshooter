class_name DialogueManagerAdapter
extends RefCounted

signal dialogue_started(dialogue_id: StringName, context: StringName)
signal line_presented(line: Dictionary)
signal choice_requested(choices: Array)
signal dialogue_finished(dialogue_id: StringName)

const PINNED_INTEGRATION_VERSION := "adapter-contract-1.0.0"

var current_dialogue_id: StringName
var current_context: StringName
var variables: Dictionary = {}
var lines: Array[Dictionary] = []
var line_index := -1
var active := false
var paused_gameplay := false
var localization_resolver: Callable

func start(definition: DialogueDefinition, supplied_variables: Dictionary = {}) -> bool:
	if definition == null or active: return false
	current_dialogue_id = definition.stable_id
	current_context = StringName(definition.context)
	variables = supplied_variables.duplicate(true)
	lines = definition.lines.duplicate(true)
	line_index = -1
	active = true
	paused_gameplay = definition.pause_gameplay
	dialogue_started.emit(current_dialogue_id, current_context)
	return advance()

func advance() -> bool:
	if not active: return false
	line_index += 1
	if line_index >= lines.size():
		finish()
		return false
	var line := _resolve_line(lines[line_index])
	line_presented.emit(line)
	var choices: Array = line.get("choices", [])
	if not choices.is_empty(): choice_requested.emit(choices)
	return true

func choose(choice_index: int) -> Dictionary:
	if not active or line_index < 0: return {}
	var choices: Array = lines[line_index].get("choices", [])
	if choice_index < 0 or choice_index >= choices.size(): return {}
	var choice: Dictionary = choices[choice_index].duplicate(true)
	for key in choice.get("set_variables", {}): variables[key] = choice.set_variables[key]
	advance()
	return choice

func finish() -> void:
	if not active: return
	var finished_id := current_dialogue_id
	active = false
	paused_gameplay = false
	dialogue_finished.emit(finished_id)

func snapshot() -> Dictionary:
	return {"dialogue_id": current_dialogue_id, "context": current_context, "variables": variables.duplicate(true), "line_index": line_index, "active": active}

func restore(definition: DialogueDefinition, state: Dictionary) -> bool:
	if definition == null or StringName(state.get("dialogue_id", "")) != definition.stable_id: return false
	current_dialogue_id = definition.stable_id; current_context = StringName(state.get("context", definition.context))
	variables = state.get("variables", {}).duplicate(true); lines = definition.lines.duplicate(true)
	line_index = clampi(int(state.get("line_index", -1)), -1, lines.size() - 1); active = bool(state.get("active", false))
	paused_gameplay = definition.pause_gameplay and active
	return true

func _resolve_line(source: Dictionary) -> Dictionary:
	var result := source.duplicate(true)
	for key in ["text", "speaker", "portrait_id"]:
		var value := String(result.get(key, ""))
		var localization_key := StringName(result.get("%s_key" % key, ""))
		if not localization_key.is_empty() and localization_resolver.is_valid(): value = String(localization_resolver.call(localization_key))
		for variable in variables: value = value.replace("{%s}" % variable, str(variables[variable]))
		result[key] = value
	return result
