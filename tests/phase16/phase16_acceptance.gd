extends SceneTree

var failures := PackedStringArray()
var passed_count := 0
var hub: ServiceHub

func _init() -> void: call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if condition:
		passed_count += 1
		print("PASS: %s" % message)
	else:
		failures.append(message)
		push_error("FAIL: %s" % message)

func _run() -> void:
	await process_frame
	hub = ServiceHub.new(); root.add_child(hub); await process_frame
	hub.saves.configure_storage("user://phase16_acceptance_%d" % Time.get_ticks_usec())
	_test_roster_and_devices()
	await _test_session_lifecycle_and_checkpoint()
	_test_camera_difficulty_wingmen_and_rewards()
	_test_campaign_and_practice_entry_points()
	if failures.is_empty():
		print("PHASE 16 ACCEPTANCE: all %d checks passed" % passed_count); quit(0)
	else:
		print("PHASE 16 ACCEPTANCE: %d check(s) failed" % failures.size()); quit(1)

func _participants() -> Array[Dictionary]:
	return [
		{"device_id": -1, "profile_id": &"profile.host", "ship_id": &"ship.vanguard", "guest": false},
		{"device_id": 7, "profile_id": &"profile.guest", "ship_id": &"ship.bastion", "guest": true}
	]

func _test_roster_and_devices() -> void:
	var roster := LocalCoopRoster.new()
	var host := roster.join(-1, &"profile.host", &"ship.vanguard")
	var duplicate_profile := roster.join(2, &"profile.host", &"ship.bastion")
	var duplicate_ship := roster.join(2, &"profile.second", &"ship.vanguard")
	var guest := roster.join(7, &"", &"ship.bastion", true)
	_assert(host.accepted and guest.accepted and not duplicate_profile.accepted and duplicate_profile.reason == &"profile_conflict" and not duplicate_ship.accepted, "join flow assigns stable slots and rejects profile and ship conflicts")
	_assert(roster.participants[0].slot_id == &"player_slot.1" and roster.participants[1].actor_id == &"player.local_2" and roster.branch_owner_slot() == &"player_slot.1", "players use stable slot and actor identity while the host owns branch choices")
	roster.lock()
	var lost_slot := roster.mark_device_disconnected(7)
	_assert(lost_slot == &"player_slot.2" and not roster.participants[1].connected and roster.reassign_device(lost_slot, 8) and roster.participants[1].connected, "controller disconnect enters a recoverable reassignment state")
	_assert(not roster.leave(&"player_slot.2"), "participants cannot leave after mission lock")

func _test_session_lifecycle_and_checkpoint() -> void:
	var mission := hub.content_database.get_definition(&"mission.stage1_vertical_slice", &"mission") as MissionDefinition
	var config := GameSessionConfig.new()
	config.mission_definition = mission
	config.selected_profiles = [&"profile.host", &"guest.local_2"]
	config.selected_ships = [&"ship.vanguard", &"ship.bastion"]
	config.loadouts = [{}, {}]
	config.stage_seed = mission.default_seed
	config.multiplayer_configuration = {"local_players": 2, "online": false, "participants": _participants(), "lives": 3, "revive_limit": 2, "revive_seconds": 0.5}
	var session := GameSession.new()
	_assert(session.configure(config, hub) and session.local_coop != null and session.local_coop.player_states.size() == 2, "two-player campaign config creates one cooperative manager over the existing actor/session framework")
	root.add_child(session); await process_frame
	var state: CoopPlayerState = session.local_coop.player_states[&"player_slot.2"]
	_assert(session.local_coop.handle_player_defeat(&"player_slot.2") and state.downed and not session.local_coop.all_players_eliminated(), "individual damage transitions a defeated teammate into the downed state")
	_assert(session.local_coop.advance_revive(&"player_slot.1", &"player_slot.2", 0.5) and not state.downed and state.revives_remaining == 1, "an active teammate can complete a limited revive")
	var checkpoint := session.create_checkpoint(&"midpoint")
	state.downed = true; state.lives = 1
	_assert(checkpoint.has("cooperative_state") and session.restore_checkpoint(checkpoint) and not state.downed and state.lives == 3 and session.local_coop.roster.participants.size() == 2, "checkpoint restore preserves exact participants, lives, and revive state")
	session.queue_free()

func _test_camera_difficulty_wingmen_and_rewards() -> void:
	var first := Node2D.new(); var second := Node2D.new(); root.add_child(first); root.add_child(second)
	first.position = Vector2.ZERO; second.position = Vector2(700, 0)
	var camera := PresentationCameraRig.new(); root.add_child(camera); camera.set_targets([first, second]); camera._apply_shared_camera_rules()
	_assert(first.position.distance_to(second.position) <= camera.soft_tether_start + 0.1 and camera.edge_warning_slots.has(&"player_slot.2"), "shared camera warns at the edge and teleports an unrecoverably separated player")
	var scaling := CoopDifficultyScaler.profile(2, 0)
	_assert(scaling.enemy_count_multiplier > 1.0 and scaling.boss_health_multiplier > 1.0 and scaling.boss_attack_additions == 1 and scaling.pickup_multiplier > 1.0, "co-op balance adds targets, boss behavior, arena pressure, and pickups instead of only multiplying health")
	_assert(CoopDifficultyScaler.remaining_wingman_slots(2, 2) == 0 and CoopDifficultyScaler.remaining_wingman_slots(2, 1) == 1, "human players replace wingman slots and remaining slots stay available to scaled AI")
	var host_profile := ProgressionProfile.new(); host_profile.profile_id = &"profile.host"
	var roster := LocalCoopRoster.new(); roster.join(-1, &"profile.host", &"ship.vanguard"); roster.join(7, &"", &"ship.bastion", true); roster.lock()
	var distributor := CoopRewardDistributor.new()
	var first_claim := distributor.distribute(&"reward.phase16", {"xp": 250, "currency": 100, "items": [&"equipment.reactor_matrix"]}, roster, {&"profile.host": host_profile})
	var duplicate_claim := distributor.distribute(&"reward.phase16", {"xp": 250, "currency": 100}, roster, {&"profile.host": host_profile})
	_assert(first_claim.claimed_profiles == [&"profile.host"] and first_claim.guest_summary.has(&"guest.local_2") and duplicate_claim.claimed_profiles.is_empty() and host_profile.currency == 100, "co-op rewards persist once for the host while guest progress is session-only and reload-safe")
	first.queue_free(); second.queue_free(); camera.queue_free()

func _test_campaign_and_practice_entry_points() -> void:
	var host := hub.profiles.get_progression_profile()
	var companion := hub.profiles.create_profile("Co-op Pilot", &"profile.phase16_companion")
	var operation := OperationOneController.new()
	_assert(operation.configure(hub.content_database, hub, host), "Operation 1 exposes the local cooperative campaign entry point")
	var selections: Array[Dictionary] = [
		{"device_id": -1, "profile_id": host.profile_id, "ship_id": &"ship.vanguard", "loadout": {}},
		{"device_id": -2, "profile_id": companion.profile_id, "ship_id": &"ship.bastion", "loadout": {}}
	]
	var config := operation.create_local_coop_config(1, selections)
	_assert(config != null and config.selected_profiles.size() == 2 and config.mode_rules.has("cooperative_difficulty"), "campaign preflight carries both profiles, ships, loadouts, and the co-op balance profile")
	var all_stages_safe := true
	for stage_number in range(1, 11):
		var mission := operation.mission_for_stage(stage_number)
		var plan := operation.generate_plan(stage_number, mission.default_seed, 50)
		if plan == null or not StageValidator.validate(plan, mission, 2).valid: all_stages_safe = false
	_assert(all_stages_safe, "all ten Operation 1 stages validate their authored two-player clearance")
	var practice_roster := LocalCoopRoster.new()
	practice_roster.join(-1, host.profile_id, &"ship.vanguard"); practice_roster.join(-2, companion.profile_id, &"ship.bastion"); practice_roster.lock()
	var practice := BossPracticeSession.new()
	_assert(practice.configure(&"boss.corsair_dreadnought", 0, 50, {}, 2) and practice.configure_local_coop(practice_roster) and practice.local_players == 2 and not practice.result_policy().grant_rewards, "boss practice accepts the same two-player roster without granting campaign rewards")
