class_name FullCampaignQARunner
extends RefCounted

const GENERATION_BUDGET_USEC := 50000

static func run(controller: FullCampaignController) -> Dictionary:
	var reports: Array[Dictionary] = []
	var seed_batches_valid := true
	var coop_valid := true
	var accessibility_valid := true
	var checkpoint_valid := true
	var mode_reuse_valid := true
	var ng_plus_valid := true
	var within_generation_budget := true
	var expected_level_valid := true
	var total_generation_usec := 0
	var original_level := controller.profile.level
	for row in controller.progression_review():
		controller.profile.level = int(row.entry_level)
		var entry_stage := (int(row.operation) - 1) * 10 + 1
		var exit_stage := int(row.operation) * 10
		expected_level_valid = expected_level_valid and controller.create_session_config(entry_stage, &"ship.vanguard") != null and controller.generate_plan(exit_stage, 0, 50) != null and int(row.required_grind_runs) == 0
	controller.profile.level = original_level
	for stage in range(1, 61):
		var mission := controller.mission_for_stage(stage)
		var started := Time.get_ticks_usec()
		var seeds_valid := true
		for seed_value in controller.review_seed_set(stage):
			var plan := controller.generate_plan(stage, int(seed_value), 50)
			if plan == null or not StageValidator.validate(plan, mission, 1).valid: seeds_valid = false
		var coop_plan := controller.generate_plan(stage, mission.default_seed, 50)
		var stage_coop_valid: bool = coop_plan != null and bool(StageValidator.validate(coop_plan, mission, 2).valid)
		var accessible_plan := controller.generate_plan(stage, mission.default_seed + 7, 35)
		var stage_accessibility_valid: bool = accessible_plan != null and bool(StageValidator.validate(accessible_plan, mission, 1).valid)
		var ng_plan := controller.generate_plan(stage, mission.default_seed + 9, 75)
		var stage_ng_valid: bool = ng_plan != null and bool(StageValidator.validate(ng_plan, mission, 1).valid) and controller.new_game_plus_preview_config(stage, mission.default_seed + 9) != null
		var stage_mode_valid: bool = controller.create_mode_reuse_config(stage, &"mode.arcade", mission.default_seed + 11) != null
		var stage_checkpoint_valid: bool = _checkpoint_round_trip(controller, stage)
		var elapsed := Time.get_ticks_usec() - started
		total_generation_usec += elapsed
		seed_batches_valid = seed_batches_valid and seeds_valid
		coop_valid = coop_valid and stage_coop_valid
		accessibility_valid = accessibility_valid and stage_accessibility_valid
		checkpoint_valid = checkpoint_valid and stage_checkpoint_valid
		mode_reuse_valid = mode_reuse_valid and stage_mode_valid
		ng_plus_valid = ng_plus_valid and stage_ng_valid
		within_generation_budget = within_generation_budget and elapsed <= GENERATION_BUDGET_USEC
		reports.append({"stage": stage, "operation": ((stage - 1) / 10) + 1, "seed_batch": seeds_valid, "local_coop": stage_coop_valid, "accessibility": stage_accessibility_valid, "checkpoint": stage_checkpoint_valid, "mode_reuse": stage_mode_valid, "new_game_plus_preview": stage_ng_valid, "generation_usec": elapsed})
	return {"stages": reports, "summary": {"stage_count": reports.size(), "seed_batches_valid": seed_batches_valid, "expected_level_valid": expected_level_valid, "local_coop_valid": coop_valid, "accessibility_valid": accessibility_valid, "checkpoint_matrix_valid": checkpoint_valid, "mode_reuse_valid": mode_reuse_valid, "new_game_plus_preview_valid": ng_plus_valid, "within_generation_budget": within_generation_budget, "total_generation_usec": total_generation_usec}}

static func _checkpoint_round_trip(controller: FullCampaignController, stage: int) -> bool:
	var config := controller.create_session_config(stage, &"ship.vanguard", {}, 50)
	if config == null: return false
	var source := GameSession.new()
	if not source.configure(config, controller.services):
		source.free()
		return false
	source.current_segment = 5
	source.current_route = [&"node.opening", &"node.checkpoint"]
	source.cleared_segment_ids = [&"segment.opening", &"segment.checkpoint"]
	source.next_segment_id = &"node.miniboss"
	source.objective_state = {"defeated": 3, "required": 8}
	var snapshot := source.create_checkpoint(&"midpoint")
	var restored := GameSession.new()
	var valid := restored.configure(config, controller.services) and restored.restore_checkpoint(snapshot)
	valid = valid and restored.current_segment == 5 and restored.next_segment_id == &"node.miniboss" and restored.objective_state.get("defeated") == 3
	source.free()
	restored.free()
	return valid
