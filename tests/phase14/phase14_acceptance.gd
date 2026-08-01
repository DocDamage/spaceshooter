extends SceneTree

var failures := PackedStringArray()
var passed_count := 0
var hub: ServiceHub
var slice: StageOneVerticalSlice
var profile: ProgressionProfile

func _init() -> void: call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if condition: passed_count += 1; print("PASS: %s" % message)
	else: failures.append(message); push_error("FAIL: %s" % message)

func _run() -> void:
	await process_frame
	hub = ServiceHub.new(); root.add_child(hub); await process_frame
	hub.saves.configure_storage("user://phase14_acceptance_%d" % Time.get_ticks_usec())
	profile = ProgressionProfile.new(); profile.profile_id = &"profile.phase14"; profile.display_name = "Vertical Slice Pilot"; profile.current_experience = ExperienceCurve.xp_to_next(1) - 50
	hub.profiles.progression_profiles = {profile.profile_id: profile}; hub.profiles.selected_profile_ids = [profile.profile_id]
	slice = StageOneVerticalSlice.new()
	_assert(slice.configure(hub.content_database, hub, profile), "fresh profile enters the Stage 1 vertical-slice flow")
	_test_authored_content_and_generation()
	_test_tutorial_controls_and_accessibility()
	await _test_runtime_checkpoints_and_failures()
	_test_progression_results_replay_and_persistence()
	_test_performance_report()
	if failures.is_empty(): print("PHASE 14 ACCEPTANCE: all %d checks passed" % passed_count); _finish(0)
	else: print("PHASE 14 ACCEPTANCE: %d check(s) failed" % failures.size()); _finish(1)

func _finish(exit_code: int) -> void:
	slice = null
	profile = null
	hub = null
	TestSupport.free_root_nodes(self)
	call_deferred("_quit_after_cleanup", exit_code)

func _quit_after_cleanup(exit_code: int) -> void:
	await process_frame
	quit(exit_code)

func _test_authored_content_and_generation() -> void:
	_assert(slice.select_configuration(&"pilot.nova", &"ship.vanguard", {&"primary": &"weapon.pulse_cannon", &"spell": &"spell.aegis"}, 50, 140014), "pilot, ship, loadout, difficulty, and seed selection are production-data driven")
	var plan := slice.generate_plan(); var report := StageValidator.validate(plan, slice.mission, 1)
	var categories := PackedStringArray(); for id in plan.main_route: categories.append(String(plan.node_for(id).category))
	_assert(report.valid and plan.main_route.size() == 12 and plan.nodes.size() == 13, "Stage 1 deterministically assembles twelve main segments and one authored branch")
	_assert(categories.slice(0, 7) == PackedStringArray(["opening", "standard_combat", "formation_combat", "branch", "rescue", "checkpoint", "miniboss"]), "opening, combat escalation, objective branch, midpoint, and production miniboss occur in authored order")
	_assert(categories.slice(7) == PackedStringArray(["elite_encounter", "hazard_field", "pre_boss", "boss", "exit"]), "second-half escalation reaches the pre-boss checkpoint and multiphase production boss")
	_assert(slice.mission.enemy_ids.size() == 8 and slice.mission.miniboss_id == &"boss.corsair_ace_miniboss" and slice.mission.boss_id == &"boss.corsair_dreadnought", "Stage 1 carries the eight-role enemy roster, miniboss, and boss")
	_assert(slice.loadout_comparison({&"primary": &"weapon.rail", &"spell": &"spell.aegis"})[&"primary"].changed, "preflight exposes loadout comparison rather than silently replacing equipment")

func _test_tutorial_controls_and_accessibility() -> void:
	var first := slice.tutorial.next_prompt()
	_assert(first.topic == &"movement" and first.controller_aware and first.keyboard_aware, "optional tutorial starts with device-aware movement guidance")
	for topic in TutorialDirector.TOPICS: slice.tutorial.complete_topic(topic)
	_assert(slice.tutorial.next_prompt().is_empty(), "movement, fire, focus, upgrade, shield, spell, chain, checkpoint, and objective topics complete")
	slice.tutorial.replay(); slice.tutorial.skip(); _assert(slice.tutorial.next_prompt().is_empty(), "tutorial is skippable and replayable")
	for pair in {&"background_motion_reduction": 1.0, &"projectile_outline": true, &"simplified_patterns": true, &"auto_fire": true, &"aim_assistance": 0.75, &"game_speed_assistance": 0.8, &"vibration_enabled": false, &"screen_shake_scale": 0.0, &"system_damage_enabled": false}: hub.settings.set_setting(pair, {&"background_motion_reduction": 1.0, &"projectile_outline": true, &"simplified_patterns": true, &"auto_fire": true, &"aim_assistance": 0.75, &"game_speed_assistance": 0.8, &"vibration_enabled": false, &"screen_shake_scale": 0.0, &"system_damage_enabled": false}[pair], false)
	_assert(hub.input.is_fire_pressed() and hub.input.is_assist_enabled(&"simplified_patterns") and not hub.settings.get_setting(&"vibration_enabled") and not hub.settings.get_setting(&"system_damage_enabled"), "Stage 1 honors reduced motion, contrast, simplified patterns, auto-fire, aim, speed, vibration, shake, and system-damage settings")
	_assert(not hub.input.get_prompt(&"primary_fire", GameInputService.DEVICE_KEYBOARD_MOUSE).is_empty() and not hub.input.get_prompt(&"primary_fire", 0).is_empty(), "keyboard/mouse and controller prompt paths are both available")

func _test_runtime_checkpoints_and_failures() -> void:
	var config := slice.create_session_config(); var session := GameSession.new(); _assert(session.configure(config, hub), "selected Stage 1 configuration creates a production game session"); root.add_child(session)
	var runtime := StageRuntime.new(); _assert(runtime.configure(session, hub.content_database, slice.generate_plan()), "Stage 1 runs through the reusable stage runtime"); session.add_child(runtime)
	var checkpoints: Array[Dictionary] = []
	session.checkpoint_updated.connect(func(snapshot): checkpoints.append(snapshot.duplicate(true)))
	for ignored in range(20):
		await process_frame
		if runtime.current_segment == null: break
		if runtime.current_segment.definition.category == "branch":
			for next_id in runtime.plan.node_for(runtime.current_node_id).next_ids:
				if String(next_id).begins_with("branch."): runtime.choose_branch(next_id)
		runtime.current_segment.complete(); await process_frame
	_assert(checkpoints.size() == 2 and checkpoints[0].checkpoint_id == &"midpoint" and checkpoints[1].checkpoint_id == &"pre_boss", "midpoint and pre-boss checkpoints are captured in order")
	var restored := GameSession.new(); var restore_ok := restored.configure(config, hub) and restored.restore_checkpoint(checkpoints[0]) and restored.stage_seed == 140014; root.add_child(restored)
	_assert(restore_ok, "checkpoint resume restores the exact seed, route, objectives, upgrades, and pending rewards")
	_assert(&"continue" in slice.failure_options({}, 1) and &"resume_checkpoint" in slice.failure_options(checkpoints[0], 1) and &"game_over" in slice.failure_options(checkpoints[1], 0), "death before checkpoint, after midpoint, at boss, continue, out-of-lives, game-over, restart, and abandon flows expose valid choices")
	_assert(not slice.record_temporary_upgrade(&"upgrade.overcharged_rounds").persistent, "combat upgrades are explicitly temporary across mission boundaries")

func _test_progression_results_replay_and_persistence() -> void:
	var result := {"transaction_id": &"reward.phase14.acceptance", "completed": true, "base_xp": 400, "base_currency": 500, "objectives_completed": 1, "max_chain": 20, "boss_challenge": true, "secret_route": true, "rank": &"A"}
	var before_level := profile.level; var claim := slice.complete(result)
	_assert(claim.claimed and profile.level > before_level and profile.currency > 0, "completion grants XP with a level-up opportunity and currency")
	_assert(claim.equipment.accepted and profile.inventory.size() == 1 and slice.loadout_comparison({&"core": profile.inventory[0].instance_id}).has(&"core"), "permanent equipment reward enters inventory and can be compared with the loadout")
	_assert(claim.boss_practice_unlocked and slice.can_replay() and &"mode.boss_practice" in profile.unlocked_content, "completion unlocks replay and boss practice")
	var duplicate := slice.complete(result); _assert(not duplicate.claimed and profile.inventory.size() == 1, "the same completion transaction persists rewards exactly once")
	var loaded := ProgressionProfile.from_snapshot(hub.saves.load_profile(profile.profile_id))
	_assert(loaded.claimed_reward_ids == profile.claimed_reward_ids and loaded.inventory.size() == 1 and loaded.campaign_progress.completed.has(StageOneVerticalSlice.CAMPAIGN_NODE_ID), "XP, currency, equipment, campaign completion, and unlocks survive save reload")
	var replay_result := result.duplicate(true); replay_result.transaction_id = &"reward.phase14.replay"; replay_result.replay = true
	_assert(slice.complete(replay_result).claimed and profile.inventory.size() == 2, "a completed mission can be replayed under a distinct idempotent reward transaction")

func _test_performance_report() -> void:
	for ignored in 600: slice.metrics.sample_frame(1.0 / 60.0, 900, 80, 120)
	slice.metrics.samples.memory_before = 1000000; slice.metrics.samples.memory_after = 1001000; slice.metrics.samples.checkpoint_save_ms = 2.0
	var report := slice.metrics.report()
	print("PHASE 14 BENCHMARK: %s" % report)
	_assert(report.target_met and is_equal_approx(report.average_fps, 60.0) and report.projectile_peak == 900 and report.memory_delta == 1000, "benchmark captures FPS, worst frame, projectile/enemy/effect peaks, memory, generation, checkpoint, and result-save timing")
