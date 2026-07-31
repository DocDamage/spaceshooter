class_name ObjectiveController
extends Node

signal objective_started(objective_id: StringName, dialogue_hook: StringName)
signal objective_updated(objective_id: StringName, current: float, target: float)
signal objective_resolved(objective_id: StringName, succeeded: bool, reward: Dictionary, dialogue_hook: StringName)

var _definitions: Dictionary = {}
var _states: Dictionary = {}

func register(definitions: Array[ObjectiveDefinition]) -> void:
	for definition in definitions:
		if definition == null: continue
		_definitions[definition.stable_id] = definition
		if not _states.has(definition.stable_id):
			_states[definition.stable_id] = {"status": &"waiting", "current": 0.0, "target": _target_for(definition), "optional": definition.optional}

func start(start_condition: StringName = &"segment_start") -> void:
	for objective_id in _definitions:
		var definition: ObjectiveDefinition = _definitions[objective_id]
		var state: Dictionary = _states[objective_id]
		if state.status == &"waiting" and definition.start_condition == start_condition:
			state.status = &"active"
			objective_started.emit(objective_id, StringName(definition.dialogue_hooks.get("start", "")))

func progress(objective_id: StringName, amount := 1.0) -> bool:
	if not _states.has(objective_id): return false
	var state: Dictionary = _states[objective_id]
	if state.status != &"active": return false
	state.current = minf(float(state.target), float(state.current) + amount)
	objective_updated.emit(objective_id, state.current, state.target)
	if state.current >= state.target: _resolve(objective_id, true)
	return true

func notify_neutral_damage() -> void:
	for objective_id in _definitions:
		var definition: ObjectiveDefinition = _definitions[objective_id]
		if definition.fail_on_neutral_damage: fail(objective_id)

func fail(objective_id: StringName) -> bool:
	if not _states.has(objective_id) or _states[objective_id].status not in [&"waiting", &"active"]: return false
	_resolve(objective_id, false)
	return true

func tick(delta: float) -> void:
	for objective_id in _definitions:
		var definition: ObjectiveDefinition = _definitions[objective_id]
		if _states[objective_id].status == &"active" and definition.objective_type in ["survive", "time_route"]:
			progress(objective_id, delta)

func required_complete(objective_ids: Array[StringName] = []) -> bool:
	var ids: Array = objective_ids if not objective_ids.is_empty() else _definitions.keys()
	for objective_id in ids:
		if not _states.has(objective_id): continue
		var state: Dictionary = _states[objective_id]
		if not bool(state.optional) and state.status != &"succeeded": return false
	return true

func snapshot() -> Dictionary:
	return _states.duplicate(true)

func restore(data: Dictionary) -> void:
	for objective_id in data:
		_states[StringName(objective_id)] = data[objective_id].duplicate(true)

func definition_for(objective_id: StringName) -> ObjectiveDefinition:
	return _definitions.get(objective_id) as ObjectiveDefinition

func state_for(objective_id: StringName) -> Dictionary:
	return _states.get(objective_id, {}).duplicate(true)

func _resolve(objective_id: StringName, succeeded: bool) -> void:
	var definition: ObjectiveDefinition = _definitions[objective_id]
	_states[objective_id].status = &"succeeded" if succeeded else &"failed"
	var hook := StringName(definition.dialogue_hooks.get("success" if succeeded else "failure", ""))
	objective_resolved.emit(objective_id, succeeded, definition.reward.duplicate(true) if succeeded else {}, hook)

func _target_for(definition: ObjectiveDefinition) -> float:
	return definition.duration_seconds if definition.objective_type in ["survive", "time_route"] else float(definition.target_count)
