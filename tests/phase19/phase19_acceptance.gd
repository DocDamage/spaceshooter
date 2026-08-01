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
	hub.saves.configure_storage("user://phase19_acceptance_%d" % Time.get_ticks_usec())
	_test_protocol_and_lobby()
	await _test_authoritative_network_lab()
	_test_disconnect_rewards_and_diagnostics()
	await _test_campaign_and_rollout()
	if failures.is_empty():
		print("PHASE 19 ACCEPTANCE: all %d checks passed" % passed_count); quit(0)
	else:
		print("PHASE 19 ACCEPTANCE: %d check(s) failed" % failures.size()); quit(1)

func _test_protocol_and_lobby() -> void:
	var manifest := NetworkProtocol.compatibility_manifest(&"campaign-60-phase19", "0.19.0")
	var mismatch := NetworkProtocol.compatibility_manifest(&"campaign-60-phase19", "0.18.0")
	var lobby := OnlineLobby.new()
	var created := lobby.create(&"profile.host", &"ship.vanguard", manifest, &"lobby.phase19")
	var blocked := lobby.join(2, &"profile.remote", &"ship.bastion", mismatch)
	var joined := lobby.join(2, &"profile.remote", &"ship.bastion", manifest)
	_assert(created and not blocked.accepted and blocked.reason == &"version_mismatch" and joined.accepted, "lobby blocks incompatible versions with a clear reason")
	lobby.select_loadout(1, &"ship.vanguard", {"weapon": &"weapon.pulse_cannon"}); lobby.select_loadout(2, &"ship.bastion", {"weapon": &"weapon.rail"})
	_assert(lobby.set_ready(1, true) and lobby.set_ready(2, true) and lobby.can_start() and lobby.start(), "two-player lobby supports profile, ship, loadout, ready, and start flow")
	var host_left := lobby.leave(1)
	_assert(host_left.mission_abort and not host_left.host_migrated, "shipping policy aborts safely instead of attempting unsupported host migration")

func _test_authoritative_network_lab() -> void:
	var lab := OnlineTestLab.new(); root.add_child(lab)
	_assert(lab.configure(190019, 100, 0.0), "online test lab creates host and client ships under simulated latency")
	lab.client.submit_local_input(Vector2.RIGHT, 0.05, true, true)
	_assert(lab.client.predictors[2].predicted_state.position.x > 320.0 and lab.advance(250) == 1, "remote movement and firing input predicts locally before reaching authority")
	var host_position: Vector2 = lab.host.world_state.actors[&"player.online_2"].position
	var snapshot := lab.host.broadcast_world_snapshot(); lab.advance(250)
	_assert(snapshot.stage_seed == 190019 and lab.client.stage_graph_hash == lab.host.stage_graph_hash and lab.client.world_state.actors[&"player.online_2"].position == host_position, "stage seed, graph, and reconciled movement remain synchronized")
	var request := {"owner_peer_id": 2, "owner_actor_id": &"player.online_2", "team": &"players", "definition_id": &"projectile.pulse", "position": host_position, "direction": Vector2.UP, "speed": 900.0, "spawn_tick": 1}
	lab.client.request_projectile_spawn(request); lab.advance(250); lab.advance(250)
	var projectile_id: StringName = lab.host.projectiles.projectiles.keys()[0]
	_assert(lab.client.projectiles.projectiles.has(projectile_id) and lab.client.projectiles.projectiles[projectile_id].owner_peer_id == 2, "projectiles replicate as authoritative spawn events instead of transform streams")
	var reflected := lab.host.authority_projectile_interaction(projectile_id, &"reflect", &"player.online_1", 1, &"player.online_1"); lab.advance(250)
	_assert(reflected.accepted and lab.client.projectiles.projectiles[projectile_id].owner_peer_id == 1 and lab.client.projectiles.projectiles[projectile_id].team == &"players", "reflected projectile retains authoritative owner and attribution")
	var damage := lab.host.authority_damage(&"player.online_2", 25.0, &"enemy.lab", 77); lab.advance(250)
	var forged := NetworkProtocol.make_message(&"damage_confirmation", 999, 2, {"actor_id": &"player.online_1", "health": 0.0}, 1)
	_assert(damage.accepted and lab.client.world_state.actors[&"player.online_2"].health == 75.0 and not lab.host.receive_message(forged), "host alone confirms damage and rejects forged client authority events")
	lab.host.authority_set_boss_phase(&"boss.lab", 2, &"phase.enrage"); lab.advance(250)
	var score := lab.host.authority_add_score(5000, &"boss_part"); var client_score := lab.client.authority_add_score(999999, &"forged")
	_assert(lab.client.world_state.boss.phase_index == 2 and score == 5000 and client_score == 0, "boss phases synchronize and latency cannot alter authoritative score")
	lab.queue_free(); await process_frame

func _test_disconnect_rewards_and_diagnostics() -> void:
	var coordinator := OnlineSessionCoordinator.new()
	var graph := {"nodes": [&"entry", &"boss"]}
	coordinator.configure(1, true, 190019, graph, [1, 2])
	var checkpoint := {"checkpoint_id": &"midpoint", "mission_id": &"mission.stage1", "seed": 190019, "pending_rewards": {"credits": 50}}
	var disconnect := coordinator.handle_disconnect(2, checkpoint, 1000)
	var reconnect := coordinator.handle_reconnect(2, 2000)
	_assert(disconnect.ai_takeover and disconnect.save_checkpoint and reconnect.accepted and reconnect.checkpoint.checkpoint_id == &"midpoint", "disconnect uses AI takeover and a bounded checkpoint-safe reconnect window")
	var first := coordinator.authority_reward_result(&"reward.online.fixed", {"xp": 100, "currency": 50}, [1, 2])
	var duplicate := coordinator.authority_reward_result(&"reward.online.fixed", {"xp": 100, "currency": 50}, [1, 2])
	_assert(first.accepted and duplicate.duplicate and coordinator.claimed_reward_transactions.size() == 1, "authoritative reward transaction cannot be duplicated")
	coordinator.diagnostics.store_local_hash(10, "local")
	_assert(not coordinator.diagnostics.verify_authority_hash(10, "authority") and coordinator.diagnostics.desync_warning_count == 1, "state hash mismatch is detected and reported as desync")
	_assert(coordinator.authority_domains().has(&"mission_seed") and coordinator.authority_domains().has(&"checkpoint") and coordinator.authority_domains().has(&"drops"), "host authority explicitly covers mission, combat, objectives, rewards, and checkpoints")
	coordinator.free()

func _test_campaign_and_rollout() -> void:
	var profile := ProgressionProfile.new(); profile.profile_id = &"profile.phase19"; profile.display_name = "Online Host"
	hub.profiles.progression_profiles = {profile.profile_id: profile}; hub.profiles.selected_profile_ids = [profile.profile_id]
	var campaign := FullCampaignController.new(); var configured := campaign.configure(hub.content_database, hub, profile)
	var selections: Array[Dictionary] = [
		{"profile_id": profile.profile_id, "ship_id": &"ship.vanguard", "loadout": {"weapon_id": &"weapon.pulse_cannon"}},
		{"profile_id": &"profile.remote", "ship_id": &"ship.bastion", "loadout": {"weapon_id": &"weapon.pulse_cannon"}}
	]
	var session_config := campaign.create_online_coop_config(1, selections, 1, 50, 190019) if configured else null
	var session := GameSession.new()
	_assert(session_config != null and session_config.validate().is_empty() and session.configure(session_config, hub) and session.online_coop != null and session.online_coop.is_host, "full campaign creates a validated host-authoritative online GameSession")
	root.add_child(session); var mission := load("res://production/missions/generated_mission.tscn").instantiate() as GeneratedMission; mission.configure(session, hub.content_database); session.add_child(mission); await process_frame
	_assert(mission.player_actors.size() == 2 and mission.player_actors[0].actor_id == &"player.online_1" and mission.player_actors[1].actor_id == &"player.online_2", "online campaign runtime spawns two stable player actors while only the local actor consumes input")
	var practice := campaign.create_online_mode_config(1, &"boss_practice", selections, 1, 50, 190020)
	var arcade := campaign.create_online_mode_config(1, &"arcade", selections, 1, 50, 190021)
	_assert(practice != null and practice.mode_rules.disable_campaign_rewards and arcade != null and not arcade.mode_rules.disable_campaign_rewards, "boss practice and arcade use the same online authority layer with mode-safe reward policy")
	var campaign_network_valid := true
	for stage_number in range(1, 61):
		var definition := campaign.mission_for_stage(stage_number); var plan := campaign.generate_plan(stage_number, definition.default_seed, 50)
		if plan == null or not StageValidator.validate(plan, definition, 2).valid: campaign_network_valid = false; break
		var host := OnlineSessionCoordinator.new(); var remote := OnlineSessionCoordinator.new(); var graph := plan.to_snapshot()
		var stage_network_valid := host.configure(1, true, definition.default_seed, graph, [1, 2]) and remote.configure(2, false, definition.default_seed, graph, [1, 2]) and host.stage_graph_hash == remote.stage_graph_hash
		host.free(); remote.free()
		if not stage_network_valid: campaign_network_valid = false; break
	_assert(campaign_network_valid, "all sixty campaign stages pass two-player clearance and matching online seed/graph preflight")
	var rollout := OnlineRolloutPolicy.new(); var ordered := true
	for tier in OnlineRolloutPolicy.ROLLOUT_ORDER: ordered = ordered and rollout.mark_validated(tier)
	_assert(ordered and rollout.next_tier() == &"complete", "online rollout gates boss practice, arcade, stage, Operation 1, then full campaign in order")
	session.queue_free(); await process_frame
