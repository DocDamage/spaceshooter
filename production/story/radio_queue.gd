class_name RadioQueue
extends RefCounted

signal message_started(message: Dictionary)
signal message_finished(message_id: StringName)

var pending: Array[Dictionary] = []
var current: Dictionary = {}
var completed_ids: Array[StringName] = []
var text_speed := 1.0

func enqueue(message: Dictionary) -> bool:
	var normalized := message.duplicate(true)
	var message_id := StringName(normalized.get("message_id", ""))
	if message_id.is_empty() or message_id in completed_ids or _contains(message_id): return false
	normalized["priority"] = int(normalized.get("priority", 0))
	normalized["objective_instruction"] = bool(normalized.get("objective_instruction", false))
	pending.append(normalized)
	pending.sort_custom(func(a, b): return int(a.priority) > int(b.priority))
	if current.is_empty(): _begin_next()
	return true

func complete_current(skipped := false) -> void:
	if current.is_empty(): return
	var message_id := StringName(current.message_id)
	if not skipped or not bool(current.get("objective_instruction", false)): completed_ids.append(message_id)
	message_finished.emit(message_id)
	current = {}
	_begin_next()

func cancel(message_id: StringName, obsolete := true) -> bool:
	if not current.is_empty() and StringName(current.message_id) == message_id:
		if bool(current.get("objective_instruction", false)) and obsolete: return false
		current = {}; _begin_next(); return true
	for index in range(pending.size() - 1, -1, -1):
		if StringName(pending[index].message_id) == message_id:
			if bool(pending[index].get("objective_instruction", false)) and obsolete: return false
			pending.remove_at(index); return true
	return false

func snapshot() -> Dictionary:
	return {"pending": pending.duplicate(true), "current": current.duplicate(true), "completed_ids": completed_ids.duplicate()}

func restore(state: Dictionary) -> void:
	pending.assign(state.get("pending", [])); current = state.get("current", {}).duplicate(true); completed_ids.assign(state.get("completed_ids", []))

func display_duration(text: String) -> float:
	return maxf(1.0, text.length() / (24.0 * maxf(0.25, text_speed)))

func _begin_next() -> void:
	if pending.is_empty(): return
	current = pending.pop_front()
	message_started.emit(current.duplicate(true))

func _contains(message_id: StringName) -> bool:
	if not current.is_empty() and StringName(current.message_id) == message_id: return true
	return pending.any(func(message): return StringName(message.message_id) == message_id)
