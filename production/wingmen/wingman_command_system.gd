class_name WingmanCommandSystem
extends RefCounted

signal command_issued(slot_id: StringName, mode: StringName)

var wingmen: Dictionary = {}

func register(wingman: WingmanRuntime) -> bool:
	if wingman == null or wingman.actor_slot == null or wingmen.has(wingman.actor_slot.slot_id): return false
	wingmen[wingman.actor_slot.slot_id] = wingman
	return true

func unregister(slot_id: StringName) -> void:
	wingmen.erase(slot_id)

func issue(slot_id: StringName, mode: StringName, target_id: StringName = &"") -> bool:
	var wingman: WingmanRuntime = wingmen.get(slot_id)
	if wingman == null or not wingman.issue_command(mode, target_id): return false
	command_issued.emit(slot_id, mode)
	return true

func issue_all(mode: StringName, target_id: StringName = &"") -> int:
	var count := 0
	for slot_id in wingmen:
		if issue(slot_id, mode, target_id): count += 1
	return count

func player_respawned(player_position: Vector2) -> void:
	for wingman in wingmen.values(): wingman.on_player_respawn(player_position)

func snapshot() -> Dictionary:
	var state := {}
	for slot_id in wingmen: state[slot_id] = wingmen[slot_id].snapshot()
	return state
