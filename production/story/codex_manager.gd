class_name CodexManager
extends RefCounted

signal entry_unlocked(entry_id: StringName)

var entries: Dictionary = {}
var unlocked_ids: Array[StringName] = []

func configure(definitions: Array[CodexEntryDefinition], restored_unlocks: Array[StringName] = []) -> void:
	entries.clear()
	for definition in definitions: entries[definition.stable_id] = definition
	unlocked_ids = restored_unlocks.duplicate()

func unlock(entry_id: StringName) -> bool:
	if not entries.has(entry_id) or entry_id in unlocked_ids: return false
	unlocked_ids.append(entry_id); entry_unlocked.emit(entry_id); return true

func unlocked_by_category(category: StringName) -> Array[CodexEntryDefinition]:
	var result: Array[CodexEntryDefinition] = []
	for entry_id in unlocked_ids:
		var entry: CodexEntryDefinition = entries.get(entry_id)
		if entry != null and StringName(entry.category) == category: result.append(entry)
	return result

func evaluate_unlocks(event: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	for entry in entries.values():
		if entry.stable_id in unlocked_ids: continue
		var matches := true
		for key in entry.unlock_rule:
			if event.get(key) != entry.unlock_rule[key]: matches = false; break
		if matches and unlock(entry.stable_id): result.append(entry.stable_id)
	return result
