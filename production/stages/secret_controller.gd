class_name SecretController
extends Node

signal secret_revealed(secret_id: StringName, unlock_segment_id: StringName, reward: Dictionary, dialogue_hook: StringName)

var _definitions: Dictionary = {}
var _progress: Dictionary = {}
var _revealed: Dictionary = {}

func register(definitions: Array[SecretDefinition]) -> void:
	for definition in definitions:
		if definition == null: continue
		_definitions[definition.stable_id] = definition
		_progress[definition.stable_id] = int(_progress.get(definition.stable_id, 0))

func trigger(trigger_type: StringName, trigger_id: StringName = &"", amount := 1) -> Array[StringName]:
	var unlocked: Array[StringName] = []
	for secret_id in _definitions:
		if _revealed.has(secret_id): continue
		var definition: SecretDefinition = _definitions[secret_id]
		if StringName(definition.trigger_type) != trigger_type: continue
		if not definition.trigger_id.is_empty() and definition.trigger_id != trigger_id: continue
		_progress[secret_id] = int(_progress.get(secret_id, 0)) + amount
		if int(_progress[secret_id]) >= definition.threshold:
			_revealed[secret_id] = true
			if not definition.unlock_segment_id.is_empty(): unlocked.append(definition.unlock_segment_id)
			secret_revealed.emit(secret_id, definition.unlock_segment_id, definition.reward.duplicate(true), definition.dialogue_hook)
	return unlocked

func snapshot() -> Dictionary:
	return {"progress": _progress.duplicate(true), "revealed": _revealed.duplicate(true)}

func restore(data: Dictionary) -> void:
	_progress = data.get("progress", {}).duplicate(true)
	_revealed = data.get("revealed", {}).duplicate(true)
