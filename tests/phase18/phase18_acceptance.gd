extends SceneTree

var failures := PackedStringArray()
var passed_count := 0
var hub: ServiceHub
var profile: ProgressionProfile
var controller: FullCampaignController

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
	hub.saves.configure_storage("user://phase18_acceptance_%d" % Time.get_ticks_usec())
	profile = ProgressionProfile.new()
	profile.profile_id = &"profile.phase18"
	profile.display_name = "Full Campaign Pilot"
	hub.profiles.progression_profiles = {profile.profile_id: profile}
	hub.profiles.selected_profile_ids = [profile.profile_id]
	controller = FullCampaignController.new()
	_assert(controller.configure(hub.content_database, hub, profile), "full campaign controller composes all six operations")
	await _test_runtime_campaign_loop()
	_test_operation_bibles_and_catalog()
	_test_seed_batches_and_identity()
	_test_fresh_profile_campaign()
	_test_campaign_outputs()
	if failures.is_empty():
		print("PHASE 18 ACCEPTANCE: all %d checks passed" % passed_count)
		quit(0)
	else:
		print("PHASE 18 ACCEPTANCE: %d check(s) failed" % failures.size())
		quit(1)

func _test_runtime_campaign_loop() -> void:
	var runtime_services := root.get_node_or_null("ProductionServices") as ServiceHub
	if runtime_services == null:
		_assert(false, "production autoload is available to the runtime campaign loop")
		return
	runtime_services.saves.configure_storage("user://phase18_runtime_%d" % Time.get_ticks_usec())
	var runtime_profile := ProgressionProfile.new()
	runtime_profile.profile_id = &"profile.phase18_runtime"
	runtime_profile.display_name = "Runtime Campaign Pilot"
	runtime_services.profiles.progression_profiles = {runtime_profile.profile_id: runtime_profile}
	runtime_services.profiles.selected_profile_ids = [runtime_profile.profile_id]
	var boot := load("res://production/boot/production_boot.tscn").instantiate() as ProductionBoot
	root.add_child(boot)
	await process_frame
	await process_frame
	var menu_ready := boot.campaign_controller != null and boot.main_menu != null
	if menu_ready:
		boot.main_menu.show_page(&"campaign", false)
		await process_frame
		menu_ready = boot.main_menu.current_page == &"campaign" and boot.main_menu.find_child("FullCampaignMap", true, false) != null
	_assert(menu_ready, "production boot exposes the full campaign map from the main menu")
	boot._launch_campaign_stage(1)
	await process_frame
	var launched := boot.session != null and boot.current_campaign_stage == 1 and boot.session.config.mission_definition.stage_number == 1
	_assert(launched, "campaign-map selection launches a generated campaign mission through GameSession")
	if launched: boot.session.complete_session(true)
	await process_frame
	_assert(boot.results_screen != null and runtime_profile.campaign_progress.get("completed", {}).size() == 1, "mission completion persists campaign progression and displays the results screen")
	boot._return_to_campaign_map()
	await process_frame
	await process_frame
	_assert(boot.main_menu != null and boot.main_menu.current_page == &"campaign" and boot.campaign_controller.stage_state(2) == &"available", "continuing from results returns to the map with the next stage unlocked")
	boot.main_menu.campaign_local_players = 2
	boot._launch_campaign_stage(1)
	await process_frame
	await process_frame
	_assert(boot.session != null and boot.session.local_coop != null and boot.mission.player_actors.size() == 2, "campaign map launches the full campaign with two local players")
	var decision_saved := boot.campaign_controller.record_campaign_decision(&"runtime_choice", &"alpha")
	var decision_reload := ProgressionProfile.from_snapshot(runtime_services.saves.load_profile(runtime_profile.profile_id))
	_assert(decision_saved and decision_reload.campaign_progress.get("decisions", {}).get("runtime_choice") == "alpha", "interactive campaign decisions persist immediately and survive reload")
	boot.queue_free()
	await process_frame
	var decision_screen := ResultsScreen.new()
	var selected := {"id": &"", "value": &""}
	decision_screen.configure_persisted(runtime_profile, {"claimed": true, "rewards": {}}, "Decision test", [{"text": "Choose Alpha", "decision_id": &"test_choice", "value": &"alpha"}])
	decision_screen.decision_selected.connect(func(id, value): selected.id = id; selected.value = value)
	root.add_child(decision_screen)
	await process_frame
	decision_screen.decision_buttons[0].pressed.emit()
	_assert(selected.id == &"test_choice" and selected.value == &"alpha" and not decision_screen.continue_button.disabled, "results UI requires and emits an authored campaign decision before continuing")
	decision_screen.queue_free()
	await process_frame

func _test_operation_bibles_and_catalog() -> void:
	_assert(hub.content_database.get_definitions_by_type(&"operation").size() == 6, "catalog contains six operation bibles")
	_assert(hub.content_database.get_definitions_by_type(&"mission").size() >= 60 and hub.content_database.get_definitions_by_type(&"campaign_node").size() == 60, "campaign contains sixty missions and sixty map nodes")
	_assert(hub.content_database.get_definitions_by_type(&"ship").size() >= 8 and hub.content_database.get_definitions_by_type(&"equipment").size() >= 17, "Operations 2-6 add specialist ships and three-piece equipment sets")
	var complete_bibles := true
	var finale_bosses := {}
	var valid_rosters := true
	var distinct_recipes := true
	var roster_fingerprints := {}
	var finale_practice_valid := true
	for operation_index in range(1, 7):
		var bible := controller.operation_definition(operation_index)
		if bible == null or bible.stage_ids.size() != 10 or bible.story_beats.size() != 10 or bible.unlocks_by_stage.size() != 10 or bible.review_seeds.size() != 10:
			complete_bibles = false
		var finale := controller.mission_for_stage(operation_index * 10)
		var boss := hub.content_database.get_definition(finale.boss_id, &"boss") as BossDefinition
		if boss == null or boss.is_miniboss or boss.phases.size() < 2: complete_bibles = false
		else:
			finale_bosses[boss.stable_id] = true
			var practice := BossPracticeSession.new()
			if not practice.configure(boss.stable_id, boss.phases.size() - 1, 60, {}, boss.phases.size()): finale_practice_valid = false
		if operation_index > 1:
			if bible.enemy_roster_ids.size() < 5 or bible.miniboss_ids.size() != 10 or bible.operation_boss_id.is_empty() or bible.secret_route_stages.is_empty() or bible.validation_plan.get("seed_batch_size") != 3 or bible.production_batches.get("mid", []).size() != 4: complete_bibles = false
			var recipe_fingerprints := {}
			var roster := PackedStringArray()
			for local_stage in range(1, 11):
				var mission := controller.mission_for_stage((operation_index - 1) * 10 + local_stage)
				for enemy_id in mission.enemy_ids:
					if hub.content_database.get_definition(enemy_id, &"enemy") == null: valid_rosters = false
					if String(enemy_id) not in roster: roster.append(String(enemy_id))
				var sequence := PackedStringArray()
				for segment in mission.recipe.required_sequence: sequence.append(String(segment.stable_id))
				recipe_fingerprints["|".join(sequence)] = true
			roster_fingerprints["|".join(roster)] = true
			if recipe_fingerprints.size() != 10: distinct_recipes = false
	_assert(complete_bibles and finale_bosses.size() == 6 and finale_practice_valid, "every operation has ten story/reward beats and a distinct multiphase boss with phase-selectable practice")
	_assert(valid_rosters and roster_fingerprints.size() == 5, "Operations 2-6 use valid and operation-specific enemy rosters")
	_assert(distinct_recipes, "all fifty produced stages have distinct authored segment sequences within their operation")
	var minibosses := {}
	var complete_story := true
	var generated_attack_fingerprints := {}
	var all_practice_configures := true
	for stage in range(1, 61):
		var mission := controller.mission_for_stage(stage)
		var miniboss := hub.content_database.get_definition(mission.miniboss_id, &"boss") as BossDefinition
		if miniboss != null and miniboss.is_miniboss: minibosses[miniboss.stable_id] = true
		if stage > 10 and miniboss != null:
			var attack := miniboss.phases[0].attack_decks[0].attack_patterns[0]
			generated_attack_fingerprints["%d:%d:%d:%.1f:%.1f" % [attack.pattern, attack.projectile_count, attack.burst_count, attack.projectile_speed, attack.cooldown]] = true
			var practice := BossPracticeSession.new()
			if not practice.configure(miniboss.stable_id, 0, 50, {}, miniboss.phases.size()): all_practice_configures = false
		if stage > 10:
			for hook in ["briefing", "results"]:
				var dialogue := hub.content_database.get_definition(StringName(mission.dialogue_hooks.get(hook, "")), &"dialogue") as DialogueDefinition
				if dialogue == null or dialogue.lines.size() < 2: complete_story = false
	_assert(minibosses.size() == 60, "all sixty stages declare distinct miniboss encounters")
	_assert(generated_attack_fingerprints.size() == 50 and all_practice_configures, "all fifty produced minibosses have distinct executable attack decks and valid practice sessions")
	var finale_results := hub.content_database.get_definition(StringName(controller.mission_for_stage(60).dialogue_hooks.results), &"dialogue") as DialogueDefinition
	_assert(complete_story and finale_results != null and finale_results.lines[-1].get("choices", []).size() == 2, "Operations 2-6 provide complete briefing/results dialogue and a final campaign decision")
	var first_generated_briefing := StringName(controller.mission_for_stage(11).dialogue_hooks.briefing)
	_assert(hub.story.start_dialogue(first_generated_briefing) and StringName(hub.story.radio_queue.current.get("message_id", "")) == first_generated_briefing, "generated campaign story hooks run through the in-mission radio service")
	hub.story.complete_radio()

func _test_seed_batches_and_identity() -> void:
	var all_seeds_valid := true
	var all_coop_safe := true
	var operation_identities := {}
	for operation_index in range(1, 7):
		var mechanics := {}
		for mechanic in controller.operation_definition(operation_index).stage_mechanics.values(): mechanics[mechanic] = true
		operation_identities[operation_index] = mechanics.keys()
		if mechanics.size() != 10: all_seeds_valid = false
	for stage in range(1, 61):
		var mission := controller.mission_for_stage(stage)
		var seeds := controller.review_seed_set(stage)
		if seeds.size() < 3: all_seeds_valid = false
		for seed_value in seeds:
			var plan := controller.generate_plan(stage, int(seed_value), 50)
			if plan == null or not StageValidator.validate(plan, mission, 1).valid: all_seeds_valid = false
		var coop_plan := controller.generate_plan(stage, mission.default_seed, 50)
		if coop_plan == null or not StageValidator.validate(coop_plan, mission, 2).valid: all_coop_safe = false
	_assert(all_seeds_valid, "every stage validates across its deterministic three-seed batch")
	_assert(all_coop_safe, "every generated campaign stage validates for two local players")
	_assert(operation_identities.size() == 6 and operation_identities.values().all(func(mechanics): return mechanics.size() == 10), "each operation carries a complete and distinct mechanical identity")

func _test_fresh_profile_campaign() -> void:
	_assert(controller.create_session_config(2, &"ship.vanguard") == null, "fresh profiles cannot skip campaign prerequisites")
	var decisions := {&"fleet_alliance": &"united", &"final_resolution": &"rebuild"}
	var all_sessions_valid := true
	var all_progression_valid := true
	for stage in range(1, 61):
		var selections: Array[Dictionary] = [
			{"device_id": -1, "profile_id": profile.profile_id, "ship_id": &"ship.vanguard", "loadout": {}},
			{"device_id": 17, "profile_id": &"profile.phase18_guest", "ship_id": &"ship.bastion", "loadout": {}, "guest": true}
		]
		var coop := controller.create_local_coop_config(stage, selections, 50)
		if coop == null or coop.selected_profiles.size() != 2 or not coop.mode_rules.has("cooperative_difficulty"): all_sessions_valid = false
		var result := controller.complete_stage(stage, {"transaction_id": StringName("reward.phase18.stage%d" % stage), "completed": true, "rank": &"B", "objectives_completed": 1, "max_chain": 10, "decisions": decisions if stage in [45, 59, 60] else {}})
		if not bool(result.get("claimed", false)) or not bool(result.get("next_stage_available", false)): all_progression_valid = false
	_assert(all_sessions_valid, "local co-op can enter every campaign stage with shared difficulty metadata")
	_assert(all_progression_valid and controller.campaign_complete(), "a fresh profile completes all sixty stages without a progression blocker")
	var duplicate := controller.complete_stage(60, {"transaction_id": &"reward.phase18.stage60", "completed": true})
	_assert(not duplicate.claimed and duplicate.duplicate, "campaign reward transactions remain idempotent")
	_assert(controller.campaign.decisions.get(&"fleet_alliance") == &"united" and controller.campaign.decisions.get(&"final_resolution") == &"rebuild", "campaign decisions survive through the final resolution")
	_assert(profile.unlocked_content.has(&"campaign.complete") and profile.unlocked_content.has(&"campaign.postgame") and profile.unlocked_content.has(&"mode.new_game_plus"), "campaign resolution awards postgame and New Game Plus unlocks")
	var generated_equipment_count := 0
	for item in profile.inventory:
		if String(item.definition_id).begins_with("equipment.operation"): generated_equipment_count += 1
	var progression_unlocks_valid := generated_equipment_count == 15
	for operation_index in range(2, 7):
		if not profile.unlocked_content.has(StringName("ship.operation%d_specialist" % operation_index)): progression_unlocks_valid = false
	for spell_id in [&"spell.storm", &"spell.warp", &"spell.gravity", &"spell.solar", &"spell.void"]:
		if not profile.unlocked_content.has(spell_id): progression_unlocks_valid = false
	_assert(progression_unlocks_valid, "campaign completion awards all specialist ships, spell beats, and fifteen equipment pieces")
	var equipment_definitions: Array[EquipmentDefinition] = []
	for definition in hub.content_database.get_definitions_by_type(&"equipment"): equipment_definitions.append(definition as EquipmentDefinition)
	var inventory := InventoryManager.new(profile, equipment_definitions)
	var equipped_set := 0
	for item in profile.inventory:
		if String(item.definition_id).begins_with("equipment.operation6_"):
			var equipment := hub.content_database.get_definition(item.definition_id, &"equipment") as EquipmentDefinition
			if inventory.equip(item.instance_id, equipment.slot, &"ship.operation6_specialist"): equipped_set += 1
	_assert(equipped_set == 3 and inventory.equipped_modifiers().size() == 4, "equipping two or more operation-set pieces activates the authored set bonus")

func _test_campaign_outputs() -> void:
	var review := controller.progression_review()
	_assert(review.size() == 6 and review.all(func(row): return row.required_grind_runs == 0 and row.story_beats == 10 and row.unlock_beats == 10), "campaign-wide progression declares zero required grind and complete reward/story pacing")
	var map := CampaignMapModel.new()
	map.configure(controller.campaign)
	_assert(map.visible_node_ids.size() == 60, "campaign map exposes the complete sixty-stage flow")
	var mode_config := controller.create_mode_reuse_config(60, &"mode.boss_rush", 186101)
	var ng_plus := controller.new_game_plus_preview_config(60, 186102)
	_assert(mode_config != null and mode_config.mode_rules.disable_campaign_rewards and ng_plus != null and ng_plus.mode_rules.new_game_plus_preview, "campaign content is reusable by modes and New Game Plus without campaign reward mutation")
	var qa := FullCampaignQARunner.run(controller)
	var summary: Dictionary = qa.summary
	_assert(summary.stage_count == 60 and summary.seed_batches_valid and summary.expected_level_valid and summary.local_coop_valid and summary.accessibility_valid, "campaign QA matrix covers all stages across seed, expected-level, solo, co-op, and accessibility runs")
	_assert(summary.checkpoint_matrix_valid and summary.mode_reuse_valid and summary.new_game_plus_preview_valid, "every stage passes checkpoint restore, mode reuse, and New Game Plus preview regression")
	_assert(summary.within_generation_budget, "all stage regression batches remain within the authored generation-time budget")
	var loaded := ProgressionProfile.from_snapshot(hub.saves.load_profile(profile.profile_id))
	_assert(loaded.campaign_progress.get("completed", {}).size() == 60 and loaded.campaign_progress.get("boss_practice", []).size() >= 66 and loaded.unlocked_content.has(&"campaign.complete") and loaded.claimed_reward_ids.size() == 60, "sixty clears, sixty minibosses, six bosses, decisions, rewards, and postgame unlocks survive save reload")
