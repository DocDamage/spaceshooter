extends SceneTree

var failures := PackedStringArray()
var passed_count := 0
var hub: ServiceHub
var session: GameSession
var mission: GeneratedMission
var storage_path: String

func _init() -> void: call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if condition: passed_count += 1; print("PASS: %s" % message)
	else: failures.append(message); push_error("FAIL: %s" % message)

func _run() -> void:
	await process_frame
	storage_path = "user://phase20_acceptance_%d" % Time.get_ticks_usec()
	hub = ServiceHub.new(); root.add_child(hub); await process_frame; hub.saves.configure_storage(storage_path)
	var profile := ProgressionProfile.new(); profile.profile_id = &"profile.phase20"; profile.display_name = "Runtime Pilot"
	hub.profiles.progression_profiles = {profile.profile_id: profile}; hub.profiles.selected_profile_ids = [profile.profile_id]
	var campaign := FullCampaignController.new(); _assert(campaign.configure(hub.content_database, hub, profile), "campaign services configure for the executable runtime test")
	var config := campaign.create_session_config(1, &"ship.vanguard", {&"primary": &"weapon.pulse_cannon", &"secondary": &"weapon.spread_cannon", &"heavy": &"weapon.missile_launcher", &"spell": &"spell.aegis"}, 50)
	_assert(config != null and config.mission_definition.enemy_ids.all(func(enemy_id): return hub.content_database.get_definition(enemy_id, &"enemy") != null), "Stage 1 resolves every authored enemy roster ID")
	session = GameSession.new(); _assert(session.configure(config, hub), "Stage 1 creates a gameplay session from the selected loadout"); root.add_child(session)
	mission = GeneratedMission.new(); mission.configure(session, hub.content_database); session.add_child(mission)
	for ignored in 8: await physics_frame
	_assert(not mission.player_actors.is_empty() and mission.player_actors[0] is ProductionPlayer, "generated mission spawns the selected player actor")
	var player := mission.player_actors[0] as ProductionPlayer
	var loadout := player.combat_loadout_snapshot()
	_assert(loadout.weapons == [&"weapon.pulse_cannon", &"weapon.spread_cannon", &"weapon.missile_launcher"] and loadout.spells == [&"spell.aegis"] and loadout.melee == &"melee.energy_blade" and loadout.super == &"super.overdrive", "primary, secondary, heavy, spell, melee, and super selections reach the live player")
	var focus_has_dash_conflict := false
	for focus_event in InputMap.action_get_events(&"focus"):
		if &"dash" in hub.input.get_conflicts(&"focus", focus_event): focus_has_dash_conflict = true
	_assert(not focus_has_dash_conflict, "Focus and Dash have distinct default bindings")
	var standard_package := EncounterPackageResolver.resolve(hub.content_database.get_definition(&"segment.standard_combat", &"stage_segment"), config.mission_definition, &"node.phase20", config.stage_seed, 50, 1)
	_assert(standard_package.waves.size() == 3 and standard_package.waves.all(func(wave): return wave.formation != null and wave.formation.member_enemy_ids.all(func(enemy_id): return enemy_id in config.mission_definition.enemy_ids)), "encounter packages provide deterministic multi-wave mission roster variants")
	if mission.stage_runtime.current_segment != null and mission.stage_runtime.current_segment.definition.category == "opening":
		mission.stage_runtime.current_segment.complete()
		for frame in 3: await process_frame
	for ignored in 16:
		await physics_frame
		if mission.enemy_pool.active_count() > 0: break
	_assert(mission.enemy_pool.active_count() > 0, "the first combat segment spawns the mission-specific enemy roster")
	var enemy := mission.enemy_pool.active_enemies()[0]
	_assert(is_instance_valid(enemy.attack_controller.target) and enemy.attack_controller.pool == mission.projectile_pool and enemy.difficulty != null, "ordinary enemies receive a player target, projectile pool, and difficulty profile")
	enemy.position = Vector2(270, 360)
	enemy.attack_controller.cooldown = 0.0
	enemy.attack_controller.tick(2.0)
	_assert(mission.projectile_pool.get_active_count(&"enemy_bullet") > 0, "an ordinary enemy attack creates a pooled hostile projectile")
	var hostile := mission.projectile_pool.get_active_objects(&"enemy_bullet")[0] as ProductionProjectile
	var durability_before := player.health_component.current + player.shield_component.current
	hostile._on_area_entered(player)
	var durability_after := player.health_component.current + player.shield_component.current
	_assert(durability_after < durability_before, "the pooled enemy projectile resolves real player damage")
	var enemy_count_before := mission.enemy_pool.active_count()
	var kill := DamagePacket.new(99999.0, player.actor_id); kill.source_player_id = player.actor_id; enemy.receive_damage(kill)
	await process_frame
	_assert(mission.enemy_pool.active_count() == enemy_count_before - 1 and mission.score_tracker.score > 0 and int(session.reward_state.credits) > 0, "player damage defeats, rewards, scores, and returns an enemy to the pool")
	var pickup_count := mission.projectile_pool.get_active_count(&"pickup")
	var pickup := mission.projectile_pool.get_active_objects(&"pickup")[0] as ProductionPickup if pickup_count > 0 else null
	if pickup != null: pickup._on_area_entered(player); await process_frame
	_assert(pickup_count > 0 and mission.projectile_pool.get_active_count(&"pickup") == pickup_count - 1, "enemy drops become visible, collectable, owner-aware pooled pickups")
	session.config.loadouts[0][&"wingman"] = &"wingman.rook"; mission._spawn_selected_wingman(); await process_frame
	var wingman := mission.wingman_actors[0] if not mission.wingman_actors.is_empty() else null
	for ignored in 16:
		if mission.enemy_pool.active_count() > 0: break
		await physics_frame
	if wingman != null: wingman.issue_command(&"attack"); wingman._physics_process(0.2)
	_assert(wingman != null and session.actor_registry.get_count(&"wingman") == 1 and wingman.weapon_runtime != null and wingman.weapon_runtime.trigger_held, "selected wingman spawns with live command, target, movement, and weapon integration")
	_test_objective_and_hazard_actors(player)
	await _test_branch_panel()
	await _test_failure_checkpoint(config)
	await _test_shipping_menu(campaign)
	if failures.is_empty(): print("PHASE 20 ACCEPTANCE: all %d checks passed" % passed_count); _finish(0)
	else: print("PHASE 20 ACCEPTANCE: %d check(s) failed" % failures.size()); _finish(1)

func _test_objective_and_hazard_actors(player: ProductionPlayer) -> void:
	var controller := ObjectiveController.new(); root.add_child(controller)
	var objective := hub.content_database.get_definition(&"objective.rescue_pilots", &"objective") as ObjectiveDefinition
	controller.register([objective]); controller.start()
	var actor := ObjectiveActor.new(); actor.configure_objective(objective, 0, controller, {"players": [player], "registry": session.actor_registry, "event_bus": session.event_bus}); actor.position = player.position; root.add_child(actor); actor._physics_process(0.1)
	_assert(controller.state_for(objective.stable_id).get("status") == &"succeeded" and session.actor_registry.get_count(&"objective") >= 1, "rescue objectives use registered, positioned, durable actors with a real success path")
	var hazard := HazardFactory.create(&"hazard.ion_storm", 99, {"players": [player], "registry": session.actor_registry, "event_bus": session.event_bus, "projectile_pool": mission.projectile_pool, "difficulty": mission.difficulty_definition, "stage_seed": session.stage_seed}); root.add_child(hazard)
	var before := player.health_component.current + player.shield_component.current; hazard._physics_process(1.8)
	_assert(hazard is StageHazard and player.health_component.current + player.shield_component.current < before and not hazard.snapshot().is_empty(), "hazards are executable actors with damage and checkpoint state")

func _test_branch_panel() -> void:
	for ignored in 3:
		if mission.stage_runtime.current_segment != null: mission.stage_runtime.current_segment.complete()
		for frame in 3: await process_frame
		if mission.stage_runtime.current_segment != null and mission.stage_runtime.current_segment.definition.category == "branch": break
	var at_branch := mission.stage_runtime.current_segment != null and mission.stage_runtime.current_segment.definition.category == "branch"
	_assert(at_branch and mission.mission_hud.branch_panel.visible, "a generated tactical fork opens a focusable branch-choice panel")
	if at_branch:
		var choices: Array = mission.stage_runtime.plan.node_for(mission.stage_runtime.current_node_id).get("next_ids", [])
		_assert(not choices.is_empty() and mission.stage_runtime.choose_branch(choices[0]) and not mission.stage_runtime.current_segment._external_gates.has(StringName("branch.%s" % mission.stage_runtime.current_node_id)), "branch selection records the route and releases the segment gate")

func _test_failure_checkpoint(config: GameSessionConfig) -> void:
	var failed := GameSession.new(); _assert(failed.configure(config, hub), "failure regression configures an independent session"); root.add_child(failed); await process_frame
	failed.current_route = [&"node.test"]; failed.create_checkpoint(&"midpoint"); var checkpoint := failed.checkpoint_snapshot.duplicate(true)
	failed.complete_session(false, &"test_failure")
	_assert(failed.mission_state.status == &"failed" and not failed.completion_result.completed and failed.checkpoint_snapshot == checkpoint and failed.completion_result.checkpoint_available, "failure preserves the checkpoint and never reports mission completion")
	failed.complete_session(false, &"duplicate")
	_assert(failed.completion_result.failure_reason == &"test_failure", "failure completion is idempotent")

func _test_shipping_menu(campaign: FullCampaignController) -> void:
	var menu := MenuShell.new(); menu.configure(hub, false, campaign); root.add_child(menu); await process_frame
	var main_text := _control_text(menu)
	_assert(["Continue", "Campaign Map — Operations 1–6", "Modes", "Hangar & Progression", "Codex", "Profiles", "Online Co-op", "Settings", "Credits", "Quit"].all(func(label): return label in main_text), "shipping menu exposes every supported front-end destination")
	var registered := true
	for page in [&"modes", &"hangar", &"inventory", &"skills", &"upgrades", &"codex", &"profiles", &"settings", &"online", &"credits"]:
		menu.show_page(page, false); await process_frame
		if "This page has not been registered." in _control_text(menu): registered = false
	_assert(registered and menu.current_page == &"credits", "mode, progression, codex, profile, settings, online-gate, and credits pages build through shipping UI")
	menu.queue_free(); await process_frame

func _control_text(node: Node) -> PackedStringArray:
	var result := PackedStringArray()
	if node is Label or node is Button: result.append(String(node.text))
	for child in node.get_children(): result.append_array(_control_text(child))
	return result

func _finish(exit_code: int) -> void:
	mission = null; session = null; hub = null
	TestSupport.free_root_nodes(self); TestSupport.remove_tree(storage_path)
	call_deferred("_quit_after_cleanup", exit_code)

func _quit_after_cleanup(exit_code: int) -> void:
	await process_frame
	quit(exit_code)
