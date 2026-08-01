class_name LocalCoopRoster
extends RefCounted

signal participant_joined(participant: Dictionary)
signal participant_left(slot_id: StringName)
signal device_recovery_required(slot_id: StringName, previous_device_id: int)

const MAX_LOCAL_PLAYERS := 2
const PLAYER_COLORS := [Color("55d9ff"), Color("ffb84d")]

var participants: Array[Dictionary] = []
var allow_duplicate_ships := false
var locked_for_mission := false

func join(device_id: int, profile_id: StringName, ship_id: StringName, guest := false) -> Dictionary:
	if locked_for_mission: return {"accepted": false, "reason": &"mission_locked"}
	if participants.size() >= MAX_LOCAL_PLAYERS: return {"accepted": false, "reason": &"roster_full"}
	if ship_id.is_empty(): return {"accepted": false, "reason": &"ship_required"}
	if participants.any(func(entry): return int(entry.device_id) == device_id): return {"accepted": false, "reason": &"device_in_use"}
	if not guest and (profile_id.is_empty() or participants.any(func(entry): return not bool(entry.guest) and StringName(entry.profile_id) == profile_id)):
		return {"accepted": false, "reason": &"profile_conflict"}
	if not allow_duplicate_ships and participants.any(func(entry): return StringName(entry.ship_id) == ship_id):
		return {"accepted": false, "reason": &"duplicate_ship"}
	var index := participants.size()
	var participant := {
		"slot_id": StringName("player_slot.%d" % (index + 1)),
		"actor_id": StringName("player.local_%d" % (index + 1)),
		"device_id": device_id,
		"profile_id": StringName("guest.local_%d" % (index + 1)) if guest else profile_id,
		"ship_id": ship_id,
		"guest": guest,
		"connected": true,
		"color": PLAYER_COLORS[index]
	}
	participants.append(participant)
	participant_joined.emit(participant.duplicate(true))
	return {"accepted": true, "participant": participant.duplicate(true)}

func leave(slot_id: StringName) -> bool:
	if locked_for_mission: return false
	for index in participants.size():
		if StringName(participants[index].slot_id) == slot_id:
			participants.remove_at(index)
			_reindex()
			participant_left.emit(slot_id)
			return true
	return false

func lock() -> bool:
	if participants.is_empty(): return false
	locked_for_mission = true
	return true

func mark_device_disconnected(device_id: int) -> StringName:
	for index in participants.size():
		if int(participants[index].device_id) == device_id:
			participants[index].connected = false
			var slot_id := StringName(participants[index].slot_id)
			device_recovery_required.emit(slot_id, device_id)
			return slot_id
	return &""

func reassign_device(slot_id: StringName, device_id: int) -> bool:
	if participants.any(func(entry): return int(entry.device_id) == device_id and StringName(entry.slot_id) != slot_id): return false
	for index in participants.size():
		if StringName(participants[index].slot_id) == slot_id:
			participants[index].device_id = device_id
			participants[index].connected = true
			return true
	return false

func snapshot() -> Dictionary:
	return {"version": 1, "participants": participants.duplicate(true), "allow_duplicate_ships": allow_duplicate_ships, "locked": locked_for_mission}

func restore(snapshot: Dictionary) -> bool:
	var restored: Array = snapshot.get("participants", [])
	if restored.is_empty() or restored.size() > MAX_LOCAL_PLAYERS: return false
	for entry in restored:
		for key in ["slot_id", "actor_id", "device_id", "profile_id", "ship_id", "guest", "color"]:
			if not entry.has(key): return false
	participants.assign(restored)
	allow_duplicate_ships = bool(snapshot.get("allow_duplicate_ships", false))
	locked_for_mission = bool(snapshot.get("locked", true))
	return true

func persistent_profile_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for participant in participants:
		if not bool(participant.guest): result.append(StringName(participant.profile_id))
	return result

func branch_owner_slot() -> StringName:
	return StringName(participants[0].slot_id) if not participants.is_empty() else &""

func _reindex() -> void:
	for index in participants.size():
		participants[index].slot_id = StringName("player_slot.%d" % (index + 1))
		participants[index].actor_id = StringName("player.local_%d" % (index + 1))
		participants[index].color = PLAYER_COLORS[index]
