class_name StoryService
extends BaseGameService

signal story_flag_changed(flag: StringName, value: Variant)
signal dialogue_event(dialogue_id: StringName, event: StringName)
signal gameplay_pause_requested(paused: bool)

var adapter := DialogueManagerAdapter.new()
var radio_queue := RadioQueue.new()
var story_flags: Dictionary = {}
var decisions: Dictionary = {}
var completed_dialogue_ids: Array[StringName] = []
var _hub: ServiceHub
var _dialogues: Dictionary = {}
var _active_definition: DialogueDefinition

func _init() -> void:
	service_id = &"story"

func initialize(context: Dictionary = {}) -> bool:
	_hub = context.get("hub")
	if _hub == null: return false
	for definition in _hub.content_database.get_definitions_by_type(&"dialogue"): _dialogues[definition.stable_id] = definition
	adapter.dialogue_finished.connect(_on_dialogue_finished)
	adapter.localization_resolver = _hub.localization.text
	var speed := float(_hub.settings.get_setting(&"text_speed", 1.0))
	radio_queue.text_speed = speed
	is_initialized = true
	return true

func start_dialogue(dialogue_id: StringName, variables: Dictionary = {}) -> bool:
	var definition: DialogueDefinition = _dialogues.get(dialogue_id)
	if definition == null: return false
	if definition.one_shot and dialogue_id in completed_dialogue_ids: return false
	if definition.context in ["combat", "objective", "stage_entry", "checkpoint", "pre_miniboss", "post_miniboss", "pre_boss", "post_boss"]:
		return queue_radio(dialogue_id, variables)
	_active_definition = _resolved_definition(definition)
	var started := adapter.start(_active_definition, _merged_variables(variables))
	if started:
		dialogue_event.emit(dialogue_id, &"started")
		if definition.pause_gameplay: gameplay_pause_requested.emit(true)
	return started

func queue_radio(dialogue_id: StringName, variables: Dictionary = {}) -> bool:
	var definition: DialogueDefinition = _dialogues.get(dialogue_id)
	if definition == null or (definition.one_shot and dialogue_id in completed_dialogue_ids): return false
	var resolved_lines := resolve_lines(definition.lines)
	var message := {"message_id": dialogue_id, "context": definition.context, "lines": resolved_lines, "variables": _merged_variables(variables), "priority": definition.priority, "objective_instruction": definition.objective_instruction, "portrait_id": resolved_lines[0].get("portrait_id", "") if not resolved_lines.is_empty() else ""}
	return radio_queue.enqueue(message)

func resolve_lines(source_lines: Array) -> Array[Dictionary]:
	var resolved: Array[Dictionary] = []
	for raw_line in source_lines:
		if not raw_line is Dictionary: continue
		var line: Dictionary = raw_line.duplicate(true)
		var decision_id := StringName(line.get("decision_id", ""))
		var variants: Dictionary = line.get("variants", {})
		if not decision_id.is_empty() and decisions.has(decision_id):
			var selected_key := str(decisions[decision_id])
			if variants.has(selected_key): line.text = str(variants[selected_key])
		line.erase("variants")
		line.erase("decision_id")
		resolved.append(line)
	return resolved

func _resolved_definition(definition: DialogueDefinition) -> DialogueDefinition:
	var resolved := definition.duplicate(true) as DialogueDefinition
	resolved.lines = resolve_lines(definition.lines)
	return resolved

func _merged_variables(variables: Dictionary) -> Dictionary:
	var merged := story_flags.duplicate(true)
	merged.merge(decisions, true)
	merged.merge(variables, true)
	return merged

func complete_radio(skipped := false) -> void:
	if radio_queue.current.is_empty(): return
	var dialogue_id := StringName(radio_queue.current.message_id)
	radio_queue.complete_current(skipped)
	if not skipped or not bool(_dialogues.get(dialogue_id).objective_instruction): mark_dialogue_complete(dialogue_id)

func set_flag(flag: StringName, value: Variant = true) -> void:
	story_flags[flag] = value
	story_flag_changed.emit(flag, value)

func record_decision(decision_id: StringName, value: Variant, allow_overwrite := false) -> bool:
	if decisions.has(decision_id) and not allow_overwrite: return false
	decisions[decision_id] = value
	return true

func mark_dialogue_complete(dialogue_id: StringName) -> void:
	if dialogue_id not in completed_dialogue_ids: completed_dialogue_ids.append(dialogue_id)
	dialogue_event.emit(dialogue_id, &"completed")

func snapshot() -> Dictionary:
	return {"flags": story_flags.duplicate(true), "decisions": decisions.duplicate(true), "completed_dialogue_ids": completed_dialogue_ids.duplicate(), "adapter": adapter.snapshot(), "radio": radio_queue.snapshot()}

func restore(state: Dictionary) -> void:
	story_flags = state.get("flags", {}).duplicate(true); decisions = state.get("decisions", {}).duplicate(true)
	completed_dialogue_ids.assign(state.get("completed_dialogue_ids", [])); radio_queue.restore(state.get("radio", {}))
	var adapter_state: Dictionary = state.get("adapter", {})
	var definition: DialogueDefinition = _dialogues.get(StringName(adapter_state.get("dialogue_id", "")))
	if definition != null: adapter.restore(definition, adapter_state)

func load_profile(profile: ProgressionProfile) -> void:
	if profile != null: restore(profile.story_state)

func save_profile(profile: ProgressionProfile) -> void:
	if profile != null: profile.story_state = snapshot()

func register_dialogue_for_test(definition: DialogueDefinition) -> void:
	_dialogues[definition.stable_id] = definition

func _on_dialogue_finished(dialogue_id: StringName) -> void:
	if _active_definition != null and _active_definition.pause_gameplay: gameplay_pause_requested.emit(false)
	mark_dialogue_complete(dialogue_id)
