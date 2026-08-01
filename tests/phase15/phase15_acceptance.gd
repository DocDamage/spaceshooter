extends SceneTree

var failures := PackedStringArray()
var passed_count := 0
var hub: ServiceHub
var profile: ProgressionProfile
var operation: OperationOneController

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
	hub = ServiceHub.new()
	root.add_child(hub)
	await process_frame
	hub.saves.configure_storage("user://phase15_acceptance_%d" % Time.get_ticks_usec())
	profile = ProgressionProfile.new()
	profile.profile_id = &"profile.phase15"
	profile.display_name = "Operation One Pilot"
	hub.profiles.progression_profiles = {profile.profile_id: profile}
	hub.profiles.selected_profile_ids = [profile.profile_id]
	operation = OperationOneController.new()
	_assert(operation.configure(hub.content_database, hub, profile), "Operation 1 configures from the production content database")
	_test_operation_bible_and_content()
	_test_stage_plans_and_checkpoints()
	_test_campaign_progression_economy_and_save()
	if failures.is_empty():
		print("PHASE 15 ACCEPTANCE: all %d checks passed" % passed_count)
		quit(0)
	else:
		print("PHASE 15 ACCEPTANCE: %d check(s) failed" % failures.size())
		quit(1)

func _test_operation_bible_and_content() -> void:
	var bible := operation.definition
	_assert(bible.stage_ids.size() == 10 and bible.stage_mechanics.size() == 10 and bible.story_beats.size() == 10, "operation bible defines ten stages, mechanics, and story beats")
	_assert(bible.faction_ids.has(&"faction.human_defense") and bible.faction_ids.has(&"faction.alien_vanguard"), "Operation 1 introduces the human defense and alien vanguard factions")
	_assert(bible.economy_targets.keys().all(func(stage): return stage in [3, 6, 10]), "economy review gates are authored after Stages 3, 6, and 10")
	var mechanics := {}
	var minibosses := {}
	var attack_identities := {}
	for stage_number in range(1, 11):
		mechanics[bible.stage_mechanics[stage_number]] = true
		var mission := operation.mission_for_stage(stage_number)
		minibosses[mission.miniboss_id] = true
		var miniboss := hub.content_database.get_definition(mission.miniboss_id, &"boss") as BossDefinition
		if miniboss != null: attack_identities[miniboss.arena_profile.get("attack_identity", mission.miniboss_id)] = true
	_assert(mechanics.size() == 10, "each stage introduces a distinct teaching mechanic")
	_assert(minibosses.size() == 10 and attack_identities.size() == 10, "all ten stages have minibosses with distinct attack identities")
	var finale := operation.mission_for_stage(10)
	var operation_boss := hub.content_database.get_definition(finale.boss_id, &"boss") as BossDefinition
	_assert(operation_boss != null and not operation_boss.is_miniboss and operation_boss.phases.size() >= 2, "Stage 10 ends with a major multiphase operation boss")
	_assert(bible.unlocks_by_stage[6].has(&"wingman.rook") and bible.unlocks_by_stage[10].has(&"operation1.complete"), "ship, weapon, pilot, wingman, spell, and finale unlock beats are data-driven")
	_assert(hub.content_database.get_definitions_by_type(&"ship").size() >= 3 and hub.content_database.get_definitions_by_type(&"pilot").size() >= 3 and hub.content_database.get_definition(&"wingman.rook", &"wingman") != null, "Operation 1 ships, pilots, and wingman are concrete validated content")
	_assert(hub.content_database.get_definition(&"dialogue.operation1_campaign_briefing", &"dialogue") != null and hub.content_database.get_definition(&"dialogue.operation1_finale", &"dialogue") != null, "operation briefings, debriefs, and finale dialogue are authored resources")

func _test_stage_plans_and_checkpoints() -> void:
	for stage_number in range(1, 11):
		var mission := operation.mission_for_stage(stage_number)
		var seeds := operation.review_seed_set(stage_number)
		var stage_valid := seeds.size() >= 3
		for seed_value in seeds:
			var plan := operation.generate_plan(stage_number, int(seed_value), 50)
			if plan == null or not StageValidator.validate(plan, mission, 1).valid:
				stage_valid = false
				continue
			var checkpoints := PackedStringArray()
			for node_id in plan.main_route:
				var kind := String(plan.node_for(node_id).get("checkpoint_kind", "none"))
				if kind != "none": checkpoints.append(kind)
			if checkpoints != PackedStringArray(["midpoint", "pre_boss"]): stage_valid = false
		_assert(stage_valid, "Stage %d seed set validates with midpoint and pre-boss recovery" % stage_number)
	var branch_plan := operation.generate_plan(8, 150802, 50)
	var finale_plan := operation.generate_plan(10, 151002, 50)
	_assert(branch_plan != null and branch_plan.nodes.size() > branch_plan.main_route.size(), "Stage 8 provides authored optional and secret branch routes")
	_assert(finale_plan != null and finale_plan.main_route.size() == 12 and finale_plan.main_route.any(func(id): return finale_plan.node_for(id).category == &"boss"), "Stage 10 uses the longer twelve-segment finale with a boss arena")

func _test_campaign_progression_economy_and_save() -> void:
	_assert(operation.create_session_config(2, &"ship.vanguard") == null, "later stages remain locked until their prerequisite is cleared")
	var currency_at_gates := {}
	for stage_number in range(1, 11):
		var config := operation.create_session_config(stage_number, &"ship.vanguard", {&"primary": &"weapon.pulse_cannon"}, 50)
		_assert(config != null and config.stage_seed == operation.mission_for_stage(stage_number).default_seed, "Stage %d becomes available in campaign order" % stage_number)
		var result := operation.complete_stage(stage_number, {"transaction_id": StringName("reward.phase15.stage%d" % stage_number), "completed": true, "rank": &"B", "objectives_completed": 1, "max_chain": 12})
		_assert(result.claimed and result.next_stage_available, "Stage %d grants idempotent rewards and advances the campaign" % stage_number)
		if stage_number in [3, 6, 10]: currency_at_gates[stage_number] = profile.currency
	var duplicate := operation.complete_stage(10, {"transaction_id": &"reward.phase15.stage10", "completed": true})
	_assert(not duplicate.claimed and duplicate.duplicate, "repeating a completion transaction cannot duplicate rewards")
	for stage_number in [3, 6, 10]:
		var target := operation.economy_checkpoint(stage_number)
		_assert(currency_at_gates[stage_number] >= int(target.currency_min) and currency_at_gates[stage_number] <= int(target.currency_max), "Stage %d fresh-profile currency stays inside its economy target" % stage_number)
	var replay_reward := RewardCalculator.calculate({"completed": true, "replay": true, "base_xp": 1000, "base_currency": 1000})
	_assert(replay_reward.currency == 700 and replay_reward.xp == 700, "replay rewards are capped at seventy percent to prevent runaway farming")
	var all_practice_available := true
	for stage_number in range(1, 11):
		var mission := operation.mission_for_stage(stage_number)
		if mission.miniboss_id not in operation.campaign.boss_practice: all_practice_available = false
		if not mission.boss_id.is_empty() and mission.boss_id not in operation.campaign.boss_practice: all_practice_available = false
	_assert(all_practice_available, "every defeated miniboss and boss unlocks a practice entry")
	_assert(operation.operation_complete() and profile.unlocked_content.has(&"campaign.operation2"), "Operation 1 completion unlocks the next campaign structure")
	var loaded := ProgressionProfile.from_snapshot(hub.saves.load_profile(profile.profile_id))
	_assert(loaded.campaign_progress.get("completed", {}).size() == 10 and loaded.unlocked_content.has(&"campaign.operation2") and loaded.claimed_reward_ids.size() == 10, "all ten clears, rewards, practice state, and Operation 2 unlock survive save reload")
