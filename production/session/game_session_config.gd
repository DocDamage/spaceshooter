class_name GameSessionConfig
extends RefCounted

var mission_definition: MissionDefinition
var selected_profiles: Array[StringName] = []
var selected_ships: Array[StringName] = []
var loadouts: Array[Dictionary] = []
var difficulty_profile: StringName = &"normal"
var stage_seed := 0
var mode_rules: Dictionary = {}
var multiplayer_configuration: Dictionary = {"local_players": 1, "online": false}

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if mission_definition == null:
		errors.append("mission_definition is required")
	if selected_profiles.is_empty():
		errors.append("At least one selected profile is required")
	if selected_ships.is_empty():
		errors.append("At least one selected ship is required")
	var local_players := int(multiplayer_configuration.get("local_players", 1))
	if local_players < 1 or local_players > 2: errors.append("Phase 16 supports one or two local players")
	if bool(multiplayer_configuration.get("online", false)):
		var online_peers: Array = multiplayer_configuration.get("peer_ids", [])
		if online_peers.size() != 2 or int(multiplayer_configuration.get("local_peer_id", 0)) not in online_peers: errors.append("Online cooperative sessions require two declared peers including the local peer")
		if int(multiplayer_configuration.get("authority_peer_id", 0)) != 1 or 1 not in online_peers: errors.append("Online cooperative sessions require peer 1 as host authority")
		if selected_profiles.size() != 2 or selected_ships.size() != 2 or loadouts.size() != 2: errors.append("Online cooperative sessions require both profile, ship, and loadout selections")
		if int(multiplayer_configuration.get("stage_seed", stage_seed)) != stage_seed: errors.append("Online stage seed must match the session seed")
		var declared_hash := str(multiplayer_configuration.get("stage_graph_hash", ""))
		if declared_hash.is_empty(): errors.append("Online stage graph compatibility hash is required")
		elif declared_hash != NetworkProtocol.canonical_state_hash(multiplayer_configuration.get("stage_graph", {})): errors.append("Online stage graph hash does not match its payload")
	if local_players > 1:
		var participants: Array = multiplayer_configuration.get("participants", [])
		# Pre-Phase-16 callers supplied parallel profile/ship arrays. Normalize them once
		# so old checkpoints and test scenes gain stable identities without a migration cliff.
		if participants.is_empty() and not selected_profiles.is_empty() and not selected_ships.is_empty():
			for index in local_players:
				var legacy_guest := index >= selected_profiles.size()
				var participant_profile := StringName("guest.local_%d" % (index + 1)) if legacy_guest else selected_profiles[index]
				var participant_ship := selected_ships[mini(index, selected_ships.size() - 1)]
				participants.append({"slot_id": StringName("player_slot.%d" % (index + 1)), "actor_id": StringName("player.local_%d" % (index + 1)), "device_id": GameInputService.DEVICE_KEYBOARD_MOUSE if index == 0 else GameInputService.UNASSIGNED_DEVICE, "profile_id": participant_profile, "ship_id": participant_ship, "guest": legacy_guest, "connected": true, "color": LocalCoopRoster.PLAYER_COLORS[index]})
				if index >= selected_profiles.size(): selected_profiles.append(participant_profile)
				if index >= selected_ships.size(): selected_ships.append(participant_ship)
				if index >= loadouts.size(): loadouts.append(loadouts[0].duplicate(true) if not loadouts.is_empty() else {})
			multiplayer_configuration.participants = participants
			multiplayer_configuration.allow_duplicate_ships = true
		if participants.size() != local_players: errors.append("Local cooperative participants must match local_players")
		if selected_ships.size() < local_players: errors.append("Each local player requires a selected ship")
	if stage_seed == 0 and mission_definition != null:
		stage_seed = mission_definition.default_seed
	return errors

func effective_player_count() -> int:
	return 2 if bool(multiplayer_configuration.get("online", false)) else int(multiplayer_configuration.get("local_players", 1))
