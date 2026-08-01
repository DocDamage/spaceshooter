class_name OnlineLobby
extends RefCounted

signal state_changed(state: StringName)
signal member_changed(peer_id: int, member: Dictionary)

const MAX_MEMBERS := 2

var lobby_id: StringName
var host_peer_id := 1
var state: StringName = &"closed"
var members: Dictionary = {}
var compatibility_manifest: Dictionary = {}
var host_migration_enabled := false

func create(host_profile_id: StringName, host_ship_id: StringName, manifest: Dictionary, requested_lobby_id: StringName = &"") -> bool:
	if host_profile_id.is_empty() or host_ship_id.is_empty(): return false
	compatibility_manifest = manifest.duplicate(true)
	if not bool(NetworkProtocol.compare_compatibility(manifest, manifest).compatible): return false
	lobby_id = requested_lobby_id if not requested_lobby_id.is_empty() else StringName("lobby.%d.%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()])
	members = {host_peer_id: _member(host_peer_id, host_profile_id, host_ship_id, true)}
	state = &"open"
	state_changed.emit(state)
	return true

func join(peer_id: int, profile_id: StringName, ship_id: StringName, manifest: Dictionary) -> Dictionary:
	if state != &"open": return {"accepted": false, "reason": &"lobby_unavailable", "message": "The lobby is no longer accepting players."}
	if peer_id < 1 or peer_id in members or members.size() >= MAX_MEMBERS: return {"accepted": false, "reason": &"lobby_full", "message": "The lobby is full."}
	var compatibility := NetworkProtocol.compare_compatibility(compatibility_manifest, manifest)
	if not bool(compatibility.compatible): return {"accepted": false, "reason": compatibility.reason, "message": compatibility.message}
	for existing in members.values():
		if StringName(existing.profile_id) == profile_id: return {"accepted": false, "reason": &"profile_conflict", "message": "That profile is already in the lobby."}
	members[peer_id] = _member(peer_id, profile_id, ship_id, false)
	member_changed.emit(peer_id, members[peer_id].duplicate(true))
	return {"accepted": true, "member": members[peer_id].duplicate(true)}

func select_loadout(peer_id: int, ship_id: StringName, loadout: Dictionary) -> bool:
	if state != &"open" or not members.has(peer_id) or ship_id.is_empty(): return false
	var member: Dictionary = members[peer_id]
	member.ship_id = ship_id; member.loadout = loadout.duplicate(true); member.ready = false
	members[peer_id] = member; member_changed.emit(peer_id, member.duplicate(true))
	return true

func set_ready(peer_id: int, ready: bool) -> bool:
	if state != &"open" or not members.has(peer_id): return false
	var member: Dictionary = members[peer_id]; member.ready = ready; members[peer_id] = member
	member_changed.emit(peer_id, member.duplicate(true))
	return true

func can_start() -> bool:
	return state == &"open" and members.size() == MAX_MEMBERS and members.values().all(func(member): return bool(member.ready))

func start() -> bool:
	if not can_start(): return false
	state = &"in_mission"; state_changed.emit(state)
	return true

func leave(peer_id: int) -> Dictionary:
	if not members.has(peer_id): return {"left": false}
	members.erase(peer_id)
	if peer_id == host_peer_id:
		if host_migration_enabled and not members.is_empty():
			host_peer_id = int(members.keys().min())
			var host: Dictionary = members[host_peer_id]; host.is_host = true; members[host_peer_id] = host
			return {"left": true, "host_migrated": true, "new_host_peer_id": host_peer_id}
		state = &"closed"; state_changed.emit(state)
		return {"left": true, "host_migrated": false, "mission_abort": true}
	return {"left": true, "host_migrated": false}

func roster_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var peer_ids: Array = members.keys(); peer_ids.sort()
	for peer_id in peer_ids: result.append(members[peer_id].duplicate(true))
	return result

func _member(peer_id: int, profile_id: StringName, ship_id: StringName, is_host: bool) -> Dictionary:
	return {"peer_id": peer_id, "slot_id": StringName("player_slot.%d" % peer_id), "actor_id": StringName("player.online_%d" % peer_id), "profile_id": profile_id, "ship_id": ship_id, "loadout": {}, "ready": false, "connected": true, "is_host": is_host}
