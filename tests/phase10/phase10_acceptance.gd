extends SceneTree

var failures := PackedStringArray()
var passed_count := 0
var database: ContentDatabase
var mission: MissionDefinition
var generator := StageGraphGenerator.new()

func _init() -> void: call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if condition: passed_count += 1; print("PASS: %s" % message)
	else: failures.append(message); push_error("FAIL: %s" % message)

func _run() -> void:
	await process_frame
	database = ContentDatabase.new(); root.add_child(database)
	_assert(database.initialize(), "Phase 10 resources pass content validation")
	mission = database.get_definition(&"mission.phase10_sample", &"mission") as MissionDefinition
	_test_content_library()
	_test_deterministic_generation()
	_test_validation_and_routes()
	_test_objectives_and_secrets()
	await _test_segment_and_checkpoint_runtime()
	_test_tools()
	if failures.is_empty(): print("PHASE 10 ACCEPTANCE: all %d checks passed" % passed_count); quit(0)
	else: print("PHASE 10 ACCEPTANCE: %d check(s) failed" % failures.size()); quit(1)

func _test_content_library() -> void:
	var categories := {}
	for content in database.get_definitions_by_type(&"stage_segment"):
		categories[String((content as StageSegmentDefinition).category)] = true
	var complete := true
	for category in StageSegmentDefinition.CATEGORIES: complete = complete and categories.has(String(category))
	_assert(mission != null and mission.recipe != null, "sample mission and recipe are resource-authored")
	_assert(complete and categories.size() >= 19, "sample library covers all 19 planned segment categories")

func _test_deterministic_generation() -> void:
	var first := generator.generate(mission, 424242, 50)
	var replay := generator.generate(mission, 424242, 50)
	var alternate := generator.generate(mission, 424243, 50)
	_assert(first != null and replay != null and first.fingerprint() == replay.fingerprint(), "a mission regenerates exactly from its seed")
	_assert(alternate != null and first.fingerprint() != alternate.fingerprint(), "independent seeded streams produce authored variation")
	var snapshot := first.to_snapshot()
	var restored := StagePlan.from_snapshot(snapshot, database)
	_assert(restored.fingerprint() == first.fingerprint(), "generated plans serialize for diagnostics and checkpoint replay")
	var start := Time.get_ticks_usec()
	for seed in 100: generator.generate(mission, 7000 + seed, 50)
	_assert(Time.get_ticks_usec() - start < 1000000, "generation is bounded and does not stall gameplay")

func _test_validation_and_routes() -> void:
	var plan := generator.generate(mission, 515151, 50)
	var report := StageValidator.validate(plan, mission, 2)
	_assert(report.valid, "structural, connector, content, and local multiplayer validation pass")
	var categories := PackedStringArray()
	for node_id in plan.main_route: categories.append(String(plan.node_for(node_id).category))
	_assert("boss" in categories and categories[categories.size() - 1] == "exit", "every generated main route reaches the boss and exit")
	var checkpoints := PackedStringArray()
	for node_id in plan.main_route:
		var kind := String(plan.node_for(node_id).checkpoint_kind)
		if kind != "none": checkpoints.append(kind)
	_assert(checkpoints == PackedStringArray(["midpoint", "pre_boss"]), "required midpoint and pre-boss checkpoints appear in order")
	var branches_valid := true
	for node in plan.nodes:
		if String(node.node_id).begins_with("branch."):
			branches_valid = branches_valid and (bool(node.can_terminate) or not node.next_ids.is_empty())
	_assert(branches_valid and plan.nodes.size() > plan.main_route.size(), "optional branches reconnect or terminate intentionally")
	var invalid := StageSegmentDefinition.new(); invalid.stable_id = &"segment.invalid"; invalid.entry_connectors.clear(); invalid.exit_connectors.clear()
	_assert(not invalid.validate_definition().is_empty(), "invalid segment definitions are rejected before generation")

func _test_objectives_and_secrets() -> void:
	var objective := ObjectiveDefinition.new(); objective.stable_id = &"objective.rescue_test"; objective.objective_type = "rescue"; objective.target_count = 2; objective.reward = {"credits": 20}
	var controller := ObjectiveController.new(); root.add_child(controller); controller.register([objective]); controller.start(); controller.progress(objective.stable_id)
	var state := controller.snapshot()
	var restored := ObjectiveController.new(); root.add_child(restored); restored.register([objective]); restored.restore(state); restored.progress(objective.stable_id)
	_assert(restored.required_complete(), "objective progress, success, and rewards serialize through checkpoints")
	var secret := SecretDefinition.new(); secret.stable_id = &"secret.test"; secret.trigger_type = "ability"; secret.trigger_id = &"spell.warp"; secret.threshold = 1; secret.unlock_segment_id = &"segment.secret"
	var secret_controller := SecretController.new(); root.add_child(secret_controller); secret_controller.register([secret])
	_assert(secret_controller.trigger(&"ability", &"spell.warp") == [&"segment.secret"], "secret triggers reveal authored routes without hard-coded scene logic")

func _test_segment_and_checkpoint_runtime() -> void:
	var services := ServiceHub.new(); root.add_child(services); services.saves.configure_storage("user://phase10_acceptance_%d" % Time.get_ticks_usec()); _assert(services.initialize_services(), "production services initialize for generated stage runtime")
	var config := GameSessionConfig.new(); config.mission_definition = mission; config.selected_profiles = [&"profile.phase10"]; config.selected_ships = [&"ship.vanguard"]; config.loadouts = [{}]; config.stage_seed = 909090; config.multiplayer_configuration = {"local_players": 2, "online": false}
	var session := GameSession.new(); _assert(session.configure(config, services), "generated stage configures for two local players"); root.add_child(session)
	var plan := generator.generate(mission, config.stage_seed, 50)
	var runtime := StageRuntime.new(); _assert(runtime.configure(session, database, plan), "complete generated stage launches without a one-off master scene"); session.add_child(runtime)
	var reached: Array[StringName] = []
	session.checkpoint_updated.connect(func(snapshot): reached.append(StringName(snapshot.checkpoint_id)))
	var chose_branch := false
	for index in plan.nodes.size():
		await process_frame
		if runtime.current_segment != null:
			if runtime.current_segment.definition.category == "branch":
				for next_id in plan.node_for(runtime.current_node_id).next_ids:
					if String(next_id).begins_with("branch."): chose_branch = runtime.choose_branch(next_id)
			runtime.current_segment.complete()
		await process_frame
	_assert(chose_branch and session.current_route.any(func(node_id): return String(node_id).begins_with("branch.")), "authored branch choices alter the traversed runtime route and reconnect")
	_assert(reached == [&"midpoint", &"pre_boss"], "authored midpoint and pre-boss events automatically create checkpoints")
	var checkpoint := session.checkpoint_snapshot
	_assert(checkpoint.has("stage_plan") and checkpoint.has("cleared_segment_ids") and checkpoint.has("next_segment_id") and checkpoint.has("route_choices") and checkpoint.has("safe_spawn"), "checkpoint captures graph, clearance, next segment, route, and safe spawn")
	var restored_session := GameSession.new(); _assert(restored_session.configure(config, services) and restored_session.restore_checkpoint(checkpoint), "exact generated route and objective state restore through GameSession")
	_assert(restored_session.stage_plan_snapshot.get("seed") == config.stage_seed and restored_session.current_route == checkpoint.route, "seed replay and local participant route survive restore")

func _test_tools() -> void:
	var preview := StagePreview.new(); preview.configure(mission)
	_assert(preview.generate_previews(3).size() == 3, "stage preview generates multiple seeds with graph diagnostics")
	var editor := MissionEditor.new(); var authored := editor.create_mission(&"mission.tool_test", "Tool Test", &"campaign.main", 2); authored.player_ship_id = &"ship.vanguard"; editor.recipe.required_sequence = mission.recipe.required_sequence; editor.recipe.minimum_segment_count = mission.recipe.required_sequence.size(); editor.recipe.maximum_segment_count = 12
	editor.assign_environment([&"space"]); editor.assign_factions([&"faction.raiders"]); editor.assign_bosses(&"enemy.guardian", &"enemy.commander"); editor.define_rewards({"credits": 100}); editor.define_dialogue_hooks({"briefing": &"dialogue.tool_test"})
	_assert(editor.generate_preview_seeds(3, 100).size() == 3 and editor.validate().is_empty(), "minimum mission editor authors metadata, recipe, factions, bosses, rewards, dialogue, and preview seeds")
